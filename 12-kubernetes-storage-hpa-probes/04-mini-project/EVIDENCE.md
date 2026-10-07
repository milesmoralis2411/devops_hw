# Evidence — Session 13 mini project (Resilient Notes)

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), metrics-server v0.9.0, 2026-10-07. Output is verbatim.

## Deploy the mini project
```text
$ kubectl apply -f .
persistentvolumeclaim/notes-data created
configmap/notes-config created
secret/notes-secret created
deployment.apps/notes created
service/notes created
horizontalpodautoscaler.autoscaling/notes created

$ kubectl rollout status deploy/notes --timeout=240s
Waiting for deployment "notes" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "notes" rollout to finish: 1 of 2 updated replicas are available...
deployment "notes" successfully rolled out

$ kubectl get pvc,deploy,pods,svc,hpa -l app=notes
NAME                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/notes-data   Bound    pvc-0d03c744-091f-4acc-a8bc-3fc007f36999   256Mi      RWO            standard       <unset>                 4s

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/notes   2/2     2            2           3s

NAME                         READY   STATUS    RESTARTS   AGE
pod/notes-7cd8c6476f-7v5xg   1/1     Running   0          3s
pod/notes-7cd8c6476f-hnxm9   1/1     Running   0          3s

NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/notes   ClusterIP   10.101.165.16   <none>        80/TCP    3s

$ kubectl get hpa notes
NAME    REFERENCE          TARGETS                                     MINPODS   MAXPODS   REPLICAS   AGE
notes   Deployment/notes   cpu: <unknown>/60%, memory: <unknown>/75%   2         8         2          4s

```

## Storage: the init container seeded the PVC
```text
$ kubectl logs notes-7cd8c6476f-7v5xg -c seed-content
seeded fresh content

$ kubectl run nclient --image=busybox:1.36 --restart=Never --rm -i --quiet -- wget -qO- http://notes
<h1>Resilient Notes</h1><p>env: production</p><p>seeded: Wed Oct  7 16:01:17 UTC 2026</p>
warning: couldn't attach to pod/nclient, falling back to streaming logs: unable to upgrade connection: container nclient not found in pod nclient_default
<h1>Resilient Notes</h1><p>env: production</p><p>seeded: Wed Oct  7 16:01:17 UTC 2026</p>

```

## Data survives Pod replacement
```text
$ kubectl exec notes-7cd8c6476f-7v5xg -c web -- sh -c 'echo "<p>edited live at $(date)</p>" >> /usr/share/nginx/html/index.html'

$ kubectl rollout restart deploy/notes
deployment.apps/notes restarted

$ kubectl rollout status deploy/notes --timeout=240s
Waiting for deployment "notes" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "notes" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "notes" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "notes" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "notes" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "notes" rollout to finish: 1 old replicas are pending termination...
deployment "notes" successfully rolled out

$ kubectl get pods -l app=notes
NAME                     READY   STATUS        RESTARTS   AGE
notes-7bf465d48f-dvpwz   1/1     Running       0          4s
notes-7bf465d48f-rgk6q   1/1     Running       0          6s
notes-7cd8c6476f-7v5xg   1/1     Terminating   0          13s

# new Pods, same PVC: the edit is still there, and the init container left it alone
$ kubectl logs notes-7bf465d48f-dvpwz -c seed-content
content already present, leaving it alone

$ kubectl exec notes-7bf465d48f-dvpwz -c web -- cat /usr/share/nginx/html/index.html
<h1>Resilient Notes</h1><p>env: production</p><p>seeded: Wed Oct  7 16:01:17 UTC 2026</p>
<p>edited live at Wed Oct  7 16:01:23 UTC 2026</p>

```

## Configuration: ConfigMap + Secret injected
```text
$ kubectl exec notes-7bf465d48f-dvpwz -c web -- sh -c 'echo APP_NAME=$APP_NAME APP_ENV=$APP_ENV API_TOKEN_LENGTH=${#API_TOKEN}'
APP_NAME=Resilient Notes APP_ENV=production API_TOKEN_LENGTH=28

```

## Probes: break /healthz and watch Kubernetes react
```text
$ kubectl describe pod notes-7bf465d48f-dvpwz | grep -E '^\s+(Liveness|Readiness|Startup):'
    Liveness:   http-get http://:80/healthz delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:  http-get http://:80/healthz delay=0s timeout=1s period=5s #success=1 #failure=3
    Startup:    http-get http://:80/healthz delay=0s timeout=1s period=2s #success=1 #failure=30

$ kubectl exec notes-7bf465d48f-dvpwz -c web -- rm /usr/share/nginx/html/healthz

# every Pod shares the PVC, so the file is gone for all of them
$ kubectl get pods -l app=notes
NAME                     READY   STATUS    RESTARTS      AGE
notes-7bf465d48f-dvpwz   0/1     Running   1 (14s ago)   45s
notes-7bf465d48f-rgk6q   0/1     Running   1 (17s ago)   47s

$ kubectl get endpointslices -l kubernetes.io/service-name=notes -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name} ready={.conditions.ready}{"\n"}{end}'
notes-7bf465d48f-rgk6q ready=false
notes-7bf465d48f-dvpwz ready=false

$ kubectl describe pod notes-7bf465d48f-dvpwz | sed -n '/^Events:/,$p' | tail -6
  Normal   Started    14s (x2 over 44s)  kubelet            spec.containers{web}: Container started
  Warning  Unhealthy  14s (x3 over 34s)  kubelet            spec.containers{web}: Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    14s                kubelet            spec.containers{web}: Container web failed liveness probe, will be restarted
  Warning  Unhealthy  14s                kubelet            spec.containers{web}: Readiness probe failed: Get "http://10.244.0.223:80/healthz": dial tcp 10.244.0.223:80: connect: connection refused
  Warning  Unhealthy  13s (x8 over 37s)  kubelet            spec.containers{web}: Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  0s (x6 over 10s)   kubelet            spec.containers{web}: Startup probe failed: HTTP probe failed with statuscode: 404

# restore the file by hand. Note: a liveness restart restarts the CONTAINER, not the Pod,
# so init containers do NOT re-run - the restarted containers kept failing their startup
# probe (events above) until the file came back.
$ kubectl exec notes-7bf465d48f-dvpwz -c web -- sh -c 'echo ok > /usr/share/nginx/html/healthz'

$ kubectl get pods -l app=notes
NAME                     READY   STATUS    RESTARTS      AGE
notes-7bf465d48f-dvpwz   1/1     Running   1 (44s ago)   75s
notes-7bf465d48f-rgk6q   1/1     Running   1 (47s ago)   77s

```

## HPA: generate load
```text
----- t+0s -----
notes   Deployment/notes   cpu: <unknown>/60%, memory: 57%/75%   2     8     2     85s
----- t+30s -----
notes   Deployment/notes   cpu: <unknown>/60%, memory: 61%/75%   2     8     2     115s
----- t+60s -----
notes   Deployment/notes   cpu: <unknown>/60%, memory: 61%/75%   2     8     2     2m25s
----- t+90s -----
notes   Deployment/notes   cpu: 120%/60%, memory: 69%/75%   2     8     2     2m56s
----- t+120s -----
notes   Deployment/notes   cpu: 120%/60%, memory: 69%/75%   2     8     4     3m26s
----- t+150s -----
notes   Deployment/notes   cpu: 76%/60%, memory: 63%/75%   2     8     4     3m56s
----- t+180s -----
notes   Deployment/notes   cpu: 76%/60%, memory: 63%/75%   2     8     4     4m27s
----- t+210s -----
notes   Deployment/notes   cpu: 61%/60%, memory: 66%/75%   2     8     4     4m57s

$ kubectl get hpa notes
NAME    REFERENCE          TARGETS                         MINPODS   MAXPODS   REPLICAS   AGE
notes   Deployment/notes   cpu: 61%/60%, memory: 66%/75%   2         8         4          5m27s

$ kubectl top pods -l app=notes
NAME                     CPU(cores)   MEMORY(bytes)   
notes-7bf465d48f-6nvl8   31m          21Mi            
notes-7bf465d48f-dvpwz   31m          20Mi            
notes-7bf465d48f-rgk6q   31m          21Mi            
notes-7bf465d48f-t6hmn   29m          22Mi            

$ kubectl get pods -l app=notes
NAME                     READY   STATUS    RESTARTS        AGE
notes-7bf465d48f-6nvl8   1/1     Running   0               2m42s
notes-7bf465d48f-dvpwz   1/1     Running   1 (4m48s ago)   5m19s
notes-7bf465d48f-rgk6q   1/1     Running   1 (4m51s ago)   5m21s
notes-7bf465d48f-t6hmn   1/1     Running   0               2m42s

$ kubectl describe hpa notes | sed -n '/^Events:/,$p'
Events:
  Type     Reason                        Age                    From                       Message
  ----     ------                        ----                   ----                       -------
  Warning  FailedGetResourceMetric       4m57s (x3 over 5m28s)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       4m57s (x3 over 5m28s)  horizontal-pod-autoscaler  failed to get memory utilization: unable to get metrics for resource memory: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  4m57s (x3 over 5m27s)  horizontal-pod-autoscaler  invalid metrics (2 invalid out of 2), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       2m57s (x8 over 4m42s)  horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
  Normal   SuccessfulRescale             2m42s                  horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target

```
