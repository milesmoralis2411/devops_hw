# Evidence — Deployment Strategies

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), Docker Desktop on Windows 11, 2026-10-07.
Output is verbatim.

## 1. Rolling update
```text
$ kubectl apply -f 01-rolling-update/deployment.yaml
deployment.apps/rolling-web created

$ kubectl rollout status deploy/rolling-web --timeout=180s
Waiting for deployment "rolling-web" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "rolling-web" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "rolling-web" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "rolling-web" rollout to finish: 3 of 4 updated replicas are available...
deployment "rolling-web" successfully rolled out

$ kubectl get pods -l app=rolling-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                            IMAGE               STATUS
rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Running
rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Running
rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Running
rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Running

$ kubectl set image deploy/rolling-web web=nginx:1.26-alpine
deployment.apps/rolling-web image updated

$ kubectl rollout status deploy/rolling-web --timeout=180s
Waiting for deployment "rolling-web" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 1 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 2 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 3 out of 4 new replicas have been updated...
Waiting for deployment "rolling-web" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "rolling-web" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "rolling-web" rollout to finish: 1 old replicas are pending termination...
deployment "rolling-web" successfully rolled out

$ kubectl get pods -l app=rolling-web --watch   # captured DURING the rollout
ADDED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Running
MODIFIED   rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Running
MODIFIED   rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Running
ADDED      rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Succeeded
DELETED    rolling-web-785f49db75-nm9gc   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Running
MODIFIED   rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Running
MODIFIED   rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Running
ADDED      rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Succeeded
DELETED    rolling-web-785f49db75-qcrfm   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Running
MODIFIED   rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Running
ADDED      rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Running
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Pending
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Succeeded
DELETED    rolling-web-785f49db75-ss7vb   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Running
MODIFIED   rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Running
MODIFIED   rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Running
MODIFIED   rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Running
MODIFIED   rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Succeeded
MODIFIED   rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Succeeded
DELETED    rolling-web-785f49db75-jt8gn   nginx:1.25-alpine   Succeeded

$ kubectl get rs -l app=rolling-web
NAME                     DESIRED   CURRENT   READY   AGE
rolling-web-785f49db75   0         0         0       27s
rolling-web-7bb84f4bf4   4         4         4       20s

$ kubectl get pods -l app=rolling-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                            IMAGE               STATUS
rolling-web-7bb84f4bf4-5lrfq   nginx:1.26-alpine   Running
rolling-web-7bb84f4bf4-68r2l   nginx:1.26-alpine   Running
rolling-web-7bb84f4bf4-bv6q2   nginx:1.26-alpine   Running
rolling-web-7bb84f4bf4-r8w4b   nginx:1.26-alpine   Running

$ kubectl rollout history deploy/rolling-web
deployment.apps/rolling-web 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>


```

## 2. Blue-Green
```text
$ kubectl apply -f 02-blue-green/blue-deployment.yaml -f 02-blue-green/green-deployment.yaml -f 02-blue-green/service.yaml
deployment.apps/web-blue created
deployment.apps/web-green created
service/bg-web created

$ kubectl rollout status deploy/web-blue --timeout=180s
Waiting for deployment "web-blue" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "web-blue" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "web-blue" rollout to finish: 2 of 3 updated replicas are available...
deployment "web-blue" successfully rolled out

$ kubectl rollout status deploy/web-green --timeout=180s
deployment "web-green" successfully rolled out

$ kubectl get deploy,pods -l app=bg-web -L version
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE   VERSION
deployment.apps/web-blue    3/3     3            3           2s    blue
deployment.apps/web-green   3/3     3            3           2s    green

NAME                             READY   STATUS    RESTARTS   AGE   VERSION
pod/web-blue-8b6b9f787-9x2z9     1/1     Running   0          2s    blue
pod/web-blue-8b6b9f787-hcn62     1/1     Running   0          2s    blue
pod/web-blue-8b6b9f787-l49px     1/1     Running   0          2s    blue
pod/web-green-85bff8bc76-7rwkt   1/1     Running   0          2s    green
pod/web-green-85bff8bc76-q59lh   1/1     Running   0          2s    green
pod/web-green-85bff8bc76-vl288   1/1     Running   0          2s    green

$ kubectl get svc bg-web -o jsonpath='{.spec.selector}'; echo
{"app":"bg-web","version":"blue"}

$ for i in 1 2 3 4; do kubectl exec curl-client -- wget -qO- http://bg-web; done   # BEFORE switch
VERSION=BLUE v1.0 pod=web-blue-8b6b9f787-l49px
VERSION=BLUE v1.0 pod=web-blue-8b6b9f787-9x2z9
VERSION=BLUE v1.0 pod=web-blue-8b6b9f787-l49px
VERSION=BLUE v1.0 pod=web-blue-8b6b9f787-l49px

$ kubectl patch svc bg-web -p '{"spec":{"selector":{"app":"bg-web","version":"green"}}}'
service/bg-web patched

$ kubectl get svc bg-web -o jsonpath='{.spec.selector}'; echo
{"app":"bg-web","version":"green"}

$ for i in 1 2 3 4; do kubectl exec curl-client -- wget -qO- http://bg-web; done   # AFTER switch
VERSION=GREEN v2.0 pod=web-green-85bff8bc76-vl288
VERSION=GREEN v2.0 pod=web-green-85bff8bc76-7rwkt
VERSION=GREEN v2.0 pod=web-green-85bff8bc76-vl288
VERSION=GREEN v2.0 pod=web-green-85bff8bc76-q59lh

$ kubectl get endpointslices -l kubernetes.io/service-name=bg-web
NAME           ADDRESSTYPE   PORTS   ENDPOINTS                             AGE
bg-web-jfzgl   IPv4          80      10.244.0.49,10.244.0.51,10.244.0.50   7s

# Instant rollback = point the selector back at blue:
$ kubectl patch svc bg-web -p '{"spec":{"selector":{"app":"bg-web","version":"blue"}}}'
service/bg-web patched

$ kubectl exec curl-client -- wget -qO- http://bg-web
VERSION=BLUE v1.0 pod=web-blue-8b6b9f787-9x2z9

```

## 3. Canary
```text
$ kubectl apply -f 03-canary/stable-deployment.yaml -f 03-canary/canary-deployment.yaml -f 03-canary/service.yaml
deployment.apps/canary-demo-stable created
deployment.apps/canary-demo-canary created
service/canary-demo created

$ kubectl rollout status deploy/canary-demo-stable --timeout=180s
Waiting for deployment "canary-demo-stable" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "canary-demo-stable" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "canary-demo-stable" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "canary-demo-stable" rollout to finish: 3 of 4 updated replicas are available...
deployment "canary-demo-stable" successfully rolled out

$ kubectl rollout status deploy/canary-demo-canary --timeout=180s
deployment "canary-demo-canary" successfully rolled out

$ kubectl get pods -l app=canary-demo -L track
NAME                                  READY   STATUS    RESTARTS   AGE   TRACK
canary-demo-canary-5f55c4474c-m9kgv   1/1     Running   0          3s    canary
canary-demo-stable-794bdf7bd4-cdwtl   1/1     Running   0          3s    stable
canary-demo-stable-794bdf7bd4-gxvcq   1/1     Running   0          3s    stable
canary-demo-stable-794bdf7bd4-mrzgp   1/1     Running   0          3s    stable
canary-demo-stable-794bdf7bd4-wp8nz   1/1     Running   0          3s    stable

$ kubectl get endpointslices -l kubernetes.io/service-name=canary-demo
NAME                ADDRESSTYPE   PORTS   ENDPOINTS                                         AGE
canary-demo-jncds   IPv4          80      10.244.0.53,10.244.0.54,10.244.0.56 + 2 more...   13s

$ for i in $(seq 1 100); do kubectl exec curl-client -- wget -qO- http://canary-demo; done | sort | uniq -c
     18 CANARY v2.0
     82 STABLE v1.0

# Promote the canary: scale it up and the stable version down
$ kubectl scale deploy/canary-demo-canary --replicas=4
deployment.apps/canary-demo-canary scaled

$ kubectl scale deploy/canary-demo-stable --replicas=1
deployment.apps/canary-demo-stable scaled

$ kubectl rollout status deploy/canary-demo-canary --timeout=180s
Waiting for deployment "canary-demo-canary" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "canary-demo-canary" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "canary-demo-canary" rollout to finish: 3 of 4 updated replicas are available...
deployment "canary-demo-canary" successfully rolled out

$ for i in $(seq 1 100); do kubectl exec curl-client -- wget -qO- http://canary-demo; done | sort | uniq -c
     82 CANARY v2.0
     18 STABLE v1.0

```

## 4. Recreate
```text
$ kubectl apply -f 04-recreate/deployment.yaml
deployment.apps/recreate-web created

$ kubectl rollout status deploy/recreate-web --timeout=180s
Waiting for deployment "recreate-web" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 3 of 4 updated replicas are available...
deployment "recreate-web" successfully rolled out

$ kubectl get pods -l app=recreate-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                             IMAGE               STATUS
recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Running
recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Running
recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Running
recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Running

$ kubectl set image deploy/recreate-web web=nginx:1.26-alpine
deployment.apps/recreate-web image updated

$ kubectl rollout status deploy/recreate-web --timeout=180s
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 out of 4 new replicas have been updated...
Waiting for deployment "recreate-web" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "recreate-web" rollout to finish: 3 of 4 updated replicas are available...
deployment "recreate-web" successfully rolled out

$ kubectl get pods -l app=recreate-web --watch   # captured DURING the update
MODIFIED   recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Running   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
ADDED      recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Pending     <none>
ADDED      recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Pending     <none>
ADDED      recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Pending     <none>
ADDED      recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
DELETED    recreate-web-5b9ff6f458-868gv   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
MODIFIED   recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
DELETED    recreate-web-5b9ff6f458-tvvdc   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
MODIFIED   recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
DELETED    recreate-web-5b9ff6f458-dzzs7   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
MODIFIED   recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Succeeded   2026-10-07T15:09:18Z
MODIFIED   recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
DELETED    recreate-web-5b9ff6f458-6hx8t   nginx:1.25-alpine   Succeeded   2026-10-07T15:08:50Z
MODIFIED   recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Running     <none>
MODIFIED   recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Running     <none>
MODIFIED   recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Pending     <none>
MODIFIED   recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Running     <none>
MODIFIED   recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Running     <none>

$ kubectl get events --field-selector involvedObject.name=recreate-web --sort-by=.lastTimestamp | tail -5
2m6s        Normal   ScalingReplicaSet   deployment/recreate-web   Scaled down replica set recreate-web-5b9ff6f458 from 4 to 0
2m5s        Normal   ScalingReplicaSet   deployment/recreate-web   Scaled up replica set recreate-web-7c4845558f from 0 to 4
10s         Normal   ScalingReplicaSet   deployment/recreate-web   Scaled up replica set recreate-web-5b9ff6f458 from 0 to 4
7s          Normal   ScalingReplicaSet   deployment/recreate-web   Scaled down replica set recreate-web-5b9ff6f458 from 4 to 0
6s          Normal   ScalingReplicaSet   deployment/recreate-web   Scaled up replica set recreate-web-7c4845558f from 0 to 4

$ kubectl get pods -l app=recreate-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                             IMAGE               STATUS
recreate-web-7c4845558f-5jlr4   nginx:1.26-alpine   Running
recreate-web-7c4845558f-llc5c   nginx:1.26-alpine   Running
recreate-web-7c4845558f-qwlx5   nginx:1.26-alpine   Running
recreate-web-7c4845558f-v6wqk   nginx:1.26-alpine   Running

```
