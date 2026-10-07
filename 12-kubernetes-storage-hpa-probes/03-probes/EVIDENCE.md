# Evidence — Probes

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), metrics-server v0.9.0, 2026-10-07. Output is verbatim.

## Probes
```text
$ kubectl apply -f 03-probes/01-all-three-probes.yaml
deployment.apps/probes-demo created
service/probes-demo created

$ kubectl rollout status deploy/probes-demo --timeout=180s
Waiting for deployment "probes-demo" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "probes-demo" rollout to finish: 1 of 2 updated replicas are available...
deployment "probes-demo" successfully rolled out

$ kubectl get pods -l app=probes-demo
NAME                           READY   STATUS    RESTARTS   AGE
probes-demo-57cdc94dff-448kt   1/1     Running   0          3s
probes-demo-57cdc94dff-tv57t   1/1     Running   0          3s

$ kubectl describe pod -l app=probes-demo | grep -E '^\s+(Liveness|Readiness|Startup):' | head -3
    Liveness:     http-get http://:80/ delay=0s timeout=2s period=10s #success=1 #failure=3
    Readiness:    http-get http://:80/ delay=0s timeout=2s period=5s #success=1 #failure=3
    Startup:      http-get http://:80/ delay=0s timeout=1s period=2s #success=1 #failure=30

$ kubectl get endpointslices -l kubernetes.io/service-name=probes-demo
NAME                ADDRESSTYPE   PORTS   ENDPOINTS                 AGE
probes-demo-d4h4t   IPv4          80      10.244.0.97,10.244.0.96   3s

```

### Failing liveness probe -> restarts
```text
$ kubectl apply -f 03-probes/02-failing-liveness.yaml
pod/failing-liveness created

$ kubectl get pod failing-liveness
NAME               READY   STATUS    RESTARTS      AGE
failing-liveness   1/1     Running   2 (14s ago)   45s

$ kubectl describe pod failing-liveness | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  46s                default-scheduler  Successfully assigned default/failing-liveness to minikube
  Normal   Pulled     15s (x3 over 45s)  kubelet            spec.containers{web}: Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
  Normal   Created    15s (x3 over 45s)  kubelet            spec.containers{web}: Container created
  Normal   Started    15s (x3 over 45s)  kubelet            spec.containers{web}: Container started
  Warning  Unhealthy  1s (x6 over 36s)   kubelet            spec.containers{web}: Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    1s (x3 over 31s)   kubelet            spec.containers{web}: Container web failed liveness probe, will be restarted

```

### Failing readiness probe -> removed from Service, never restarted
```text
$ kubectl apply -f 03-probes/03-failing-readiness.yaml
pod/failing-readiness created

$ kubectl get pod failing-readiness
NAME                READY   STATUS    RESTARTS   AGE
failing-readiness   0/1     Running   0          30s

# it carries app=probes-demo, yet the Service does not route to it
$ kubectl get endpointslices -l kubernetes.io/service-name=probes-demo -o jsonpath='{range .items[*].endpoints[*]}{.targetRef.name}  ready={.conditions.ready}{"\n"}{end}'
probes-demo-57cdc94dff-448kt  ready=true
probes-demo-57cdc94dff-tv57t  ready=true
failing-readiness  ready=false

$ kubectl describe pod failing-readiness | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  30s               default-scheduler  Successfully assigned default/failing-readiness to minikube
  Normal   Pulled     30s               kubelet            spec.containers{web}: Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
  Normal   Created    30s               kubelet            spec.containers{web}: Container created
  Normal   Started    30s               kubelet            spec.containers{web}: Container started
  Warning  Unhealthy  4s (x5 over 24s)  kubelet            spec.containers{web}: Readiness probe failed: HTTP probe failed with statuscode: 404

```

### exec and tcpSocket probe handlers
```text
$ kubectl apply -f 03-probes/04-exec-and-tcp-probes.yaml
pod/probe-handlers created

$ kubectl wait --for=condition=Ready pod/probe-handlers --timeout=120s
pod/probe-handlers condition met

$ kubectl get pod probe-handlers
NAME             READY   STATUS    RESTARTS   AGE
probe-handlers   2/2     Running   0          6s

# /tmp/healthy is deleted after 30s, so the exec liveness probe starts failing
$ kubectl get pod probe-handlers
NAME             READY   STATUS    RESTARTS   AGE
probe-handlers   2/2     Running   0          61s

$ kubectl get pod probe-handlers -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount} ready={.ready}{"\n"}{end}'
exec-probe: restarts=0 ready=true
tcp-probe: restarts=0 ready=true

$ kubectl describe pod probe-handlers | sed -n '/^Events:/,$p' | grep -iE 'unhealthy|killing|cat:' | head -5
  Warning  Unhealthy  21s (x2 over 26s)  kubelet            spec.containers{exec-probe}: Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
  Normal   Killing    21s                kubelet            spec.containers{exec-probe}: Container exec-probe failed liveness probe, will be restarted

```
