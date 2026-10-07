# Evidence — Troubleshooting mini project (Yatri Shop)

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), 2026-10-07. Output is verbatim.

## Deploy the broken shop
```text
$ kubectl apply -f broken/
configmap/shop-api-conf created
deployment.apps/shop-api created
service/api-svc created
configmap/shop-frontend-conf created
deployment.apps/shop-frontend created
service/shop-frontend created

$ kubectl get deploy,pods,svc -l 'app in (shop-api,shop-frontend)'
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/shop-api        0/2     2            0           31s
deployment.apps/shop-frontend   0/2     2            0           31s

NAME                                 READY   STATUS    RESTARTS   AGE
pod/shop-api-648f8ffcb7-c85lw        0/1     Running   0          31s
pod/shop-api-648f8ffcb7-r44lb        0/1     Running   0          31s
pod/shop-frontend-794ccfbc4d-4zmmh   0/1     Pending   0          31s
pod/shop-frontend-794ccfbc4d-7ktjq   0/1     Pending   0          31s

$ kubectl get pods
NAME                             READY   STATUS    RESTARTS   AGE
php-apache-5899f79df5-nckd6      1/1     Running   0          53s
shop-api-648f8ffcb7-c85lw        0/1     Running   0          31s
shop-api-648f8ffcb7-r44lb        0/1     Running   0          31s
shop-frontend-794ccfbc4d-4zmmh   0/1     Pending   0          31s
shop-frontend-794ccfbc4d-7ktjq   0/1     Pending   0          31s

```

## Bug 1 - frontend Pods stuck in Pending
```text
# Identify
$ kubectl get pods -l app=shop-frontend
NAME                             READY   STATUS    RESTARTS   AGE
shop-frontend-794ccfbc4d-4zmmh   0/1     Pending   0          31s
shop-frontend-794ccfbc4d-7ktjq   0/1     Pending   0          31s

# Investigate
$ kubectl describe pod shop-frontend-794ccfbc4d-4zmmh | sed -n '/^Events:/,$p'
Events:
  Type     Reason            Age               From               Message
  ----     ------            ----              ----               -------
  Warning  FailedScheduling  7s (x3 over 31s)  default-scheduler  0/1 nodes are available: 1 Insufficient cpu. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

$ kubectl describe node minikube | sed -n '/Allocatable:/,/System Info:/p' | grep -E 'cpu|memory'
  cpu:                24
  memory:             7984824Ki

$ kubectl get deploy shop-frontend -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo
{"limits":{"cpu":"32","memory":"64Mi"},"requests":{"cpu":"32","memory":"16Mi"}}

# Root cause: requests.cpu=32 but the node only has 24 allocatable CPUs
# Fix
$ kubectl set resources deploy/shop-frontend --requests=cpu=20m --limits=cpu=100m
deployment.apps/shop-frontend resource requirements updated

# Verify
$ kubectl get pods -l app=shop-frontend
NAME                             READY   STATUS   RESTARTS      AGE
shop-frontend-6bfc65f76d-hkwjb   0/1     Error    2 (21s ago)   25s
shop-frontend-6bfc65f76d-n2d8w   0/1     Error    2 (20s ago)   24s

```

## Bug 2 - frontend now CrashLoopBackOff
```text
# Identify
$ kubectl get pods -l app=shop-frontend
NAME                             READY   STATUS   RESTARTS      AGE
shop-frontend-6bfc65f76d-hkwjb   0/1     Error    2 (21s ago)   25s
shop-frontend-6bfc65f76d-n2d8w   0/1     Error    2 (20s ago)   24s

# Investigate
$ kubectl logs shop-frontend-6bfc65f76d-hkwjb
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: can not modify /etc/nginx/conf.d/default.conf (read-only file system?)
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/10/07 15:47:36 [emerg] 1#1: host not found in upstream "api" in /etc/nginx/conf.d/default.conf:5
nginx: [emerg] host not found in upstream "api" in /etc/nginx/conf.d/default.conf:5

$ kubectl get configmap shop-frontend-conf -o jsonpath='{.data.default\.conf}'
server {
  listen 80;
  location = / { default_type text/html; return 200 "<h1>Yatri Shop</h1>\n"; }
  location /api/ {
    proxy_pass http://api:8080;     # BUG: the Service is called api-svc
  }
}

$ kubectl get svc
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
api-svc         ClusterIP   10.106.169.211   <none>        8080/TCP       58s
kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        46m
php-apache      ClusterIP   10.103.25.245    <none>        80/TCP         80s
shop-frontend   NodePort    10.98.210.170    <none>        80:30081/TCP   58s

# Root cause: nginx resolves "api" at startup; no Service is named "api" (it is "api-svc"),
# so nginx exits with [emerg] host not found -> the container restarts forever.
# Fix
configmap/shop-frontend-conf configured
$ kubectl rollout restart deploy/shop-frontend
deployment.apps/shop-frontend restarted

$ kubectl rollout status deploy/shop-frontend --timeout=120s
Waiting for deployment "shop-frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-frontend" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-frontend" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-frontend" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-frontend" rollout to finish: 1 old replicas are pending termination...
deployment "shop-frontend" successfully rolled out

# Verify
$ kubectl get pods -l app=shop-frontend
NAME                             READY   STATUS    RESTARTS      AGE
shop-frontend-677889d55b-ksvhq   1/1     Running   0             2s
shop-frontend-677889d55b-qk2bv   1/1     Running   0             1s
shop-frontend-6bfc65f76d-n2d8w   0/1     Error     2 (24s ago)   28s

```

## Bug 3 - frontend Pods are Running, but the site does not answer
```text
# Identify
$ curl http://<node-ip>:30081/
 [HTTP 000]ssh: Process exited with status 7

# Investigate
$ kubectl get endpointslices -l kubernetes.io/service-name=shop-frontend
NAME                  ADDRESSTYPE   PORTS     ENDPOINTS   AGE
shop-frontend-rwp96   IPv4          <unset>   <unset>     62s

$ kubectl get svc shop-frontend -o jsonpath='{.spec.selector}'; echo
{"app":"frontend"}

$ kubectl get pods -l app=shop-frontend --show-labels
NAME                             READY   STATUS    RESTARTS   AGE   LABELS
shop-frontend-677889d55b-ksvhq   1/1     Running   0          4s    app=shop-frontend,pod-template-hash=677889d55b
shop-frontend-677889d55b-qk2bv   1/1     Running   0          3s    app=shop-frontend,pod-template-hash=677889d55b

# Root cause: Service selects app=frontend, Pods are labelled app=shop-frontend -> zero endpoints
# Fix
$ kubectl patch svc shop-frontend -p '{"spec":{"selector":{"app":"shop-frontend"}}}'
service/shop-frontend patched

# Verify
$ kubectl get endpointslices -l kubernetes.io/service-name=shop-frontend
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
shop-frontend-rwp96   IPv4          80      10.244.0.174,10.244.0.175   66s

$ curl http://<node-ip>:30081/
<h1>Yatri Shop</h1>
 [HTTP 200]
```

## Bug 4 - the home page works, /api/products returns an error
```text
# Identify
$ curl http://<node-ip>:30081/api/products
<html>

<head><title>502 Bad Gateway</title></head>

<body>

<center><h1>502 Bad Gateway</h1></center>

<hr><center>nginx/1.25.5</center>

</body>

</html>

 [HTTP 502]
# Investigate
$ kubectl get pods -l app=shop-api
NAME                        READY   STATUS    RESTARTS   AGE
shop-api-648f8ffcb7-c85lw   0/1     Running   0          68s
shop-api-648f8ffcb7-r44lb   0/1     Running   0          68s

$ kubectl get endpointslices -l kubernetes.io/service-name=api-svc
NAME            ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
api-svc-jtd8q   IPv4          80      10.244.0.170,10.244.0.171   68s

$ kubectl describe pod shop-api-648f8ffcb7-c85lw | sed -n '/^Events:/,$p' | grep -i readiness
  Warning  Unhealthy  68s                kubelet            spec.containers{api}: Readiness probe failed: Get "http://10.244.0.171:8080/health": dial tcp 10.244.0.171:8080: connect: connection refused
  Warning  Unhealthy  1s (x15 over 67s)  kubelet            spec.containers{api}: Readiness probe failed: HTTP probe failed with statuscode: 404

# test both paths from inside the Pod (127.0.0.1: busybox resolves "localhost" to ::1 and nginx listens on IPv4 only)
$ kubectl exec shop-api-648f8ffcb7-c85lw -- wget -qO- http://127.0.0.1:8080/health
wget: server returned error: HTTP/1.1 404 Not Found
command terminated with exit code 1

$ kubectl exec shop-api-648f8ffcb7-c85lw -- wget -qO- http://127.0.0.1:8080/healthz
ok

# Root cause: the readiness probe checks /health (404). The app serves /healthz.
# The Pods never become Ready, so api-svc has no ready endpoints.
# Fix
$ kubectl patch deploy shop-api --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/healthz"}]'
deployment.apps/shop-api patched

$ kubectl rollout status deploy/shop-api --timeout=120s
Waiting for deployment "shop-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "shop-api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "shop-api" rollout to finish: 1 old replicas are pending termination...
deployment "shop-api" successfully rolled out

# Verify
$ kubectl get pods -l app=shop-api
NAME                        READY   STATUS        RESTARTS   AGE
shop-api-648f8ffcb7-c85lw   0/1     Terminating   0          74s
shop-api-6df5ddd57f-l2t28   1/1     Running       0          5s
shop-api-6df5ddd57f-t548q   1/1     Running       0          2s

$ curl http://<node-ip>:30081/api/products
<html>

<head><title>502 Bad Gateway</title></head>

<body>

<center><h1>502 Bad Gateway</h1></center>

<hr><center>nginx/1.25.5</center>

</body>

</html>

 [HTTP 502]
```

## Bug 5 - Pods Ready, endpoints present, still failing
```text
# Investigate
$ kubectl get endpointslices -l kubernetes.io/service-name=api-svc
NAME            ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
api-svc-jtd8q   IPv4          80      10.244.0.176,10.244.0.177   76s

$ kubectl get svc api-svc -o jsonpath='port={.spec.ports[0].port} targetPort={.spec.ports[0].targetPort}'; echo
port=8080 targetPort=80

$ kubectl get pod shop-api-6df5ddd57f-l2t28 -o jsonpath='{.spec.containers[0].ports}'; echo
[{"containerPort":8080,"protocol":"TCP"}]

$ kubectl exec shop-api-6df5ddd57f-l2t28 -- netstat -tln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      

$ kubectl exec shop-frontend-677889d55b-ksvhq -- wget -qO- -T 3 http://api-svc:8080/api/products
wget: can't connect to remote host (10.106.169.211): Connection refused
command terminated with exit code 1

$ kubectl logs shop-frontend-677889d55b-ksvhq --tail=3
2026/10/07 15:47:46 [notice] 1#1: start worker process 43
2026/10/07 15:47:46 [notice] 1#1: start worker process 44
10.244.0.1 - - [07/Oct/2026:15:47:53 +0000] "GET / HTTP/1.1" 200 20 "-" "curl/7.88.1" "-"

# Root cause: api-svc forwards to targetPort 80, but nginx in the API Pod listens on 8080
# -> connection refused -> the frontend proxy returns 502 Bad Gateway
# Fix
$ kubectl patch svc api-svc --type=json -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
service/api-svc patched

# Verify
$ kubectl get endpointslices -l kubernetes.io/service-name=api-svc
NAME            ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
api-svc-jtd8q   IPv4          8080    10.244.0.176,10.244.0.177   81s

$ curl http://<node-ip>:30081/
<h1>Yatri Shop</h1>
 [HTTP 200]
$ curl http://<node-ip>:30081/api/products
[{"id":1,"name":"Masala Chai","price":20},{"id":2,"name":"Samosa","price":15}]
 [HTTP 200]
```

## Final state and drift check against fixed/
```text
$ kubectl get deploy,pods,svc -l 'app in (shop-api,shop-frontend)'
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/shop-api        2/2     2            2           82s
deployment.apps/shop-frontend   2/2     2            2           82s

NAME                                 READY   STATUS    RESTARTS   AGE
pod/shop-api-6df5ddd57f-l2t28        1/1     Running   0          13s
pod/shop-api-6df5ddd57f-t548q        1/1     Running   0          10s
pod/shop-frontend-677889d55b-ksvhq   1/1     Running   0          23s
pod/shop-frontend-677889d55b-qk2bv   1/1     Running   0          22s

$ kubectl get pods
NAME                              READY   STATUS    RESTARTS   AGE
load-generator-79554b65fc-cxwcr   1/1     Running   0          9s
load-generator-79554b65fc-h7mk4   1/1     Running   0          9s
load-generator-79554b65fc-jbd5t   1/1     Running   0          9s
php-apache-5899f79df5-nckd6       1/1     Running   0          104s
shop-api-6df5ddd57f-l2t28         1/1     Running   0          13s
shop-api-6df5ddd57f-t548q         1/1     Running   0          10s
shop-frontend-677889d55b-ksvhq    1/1     Running   0          23s
shop-frontend-677889d55b-qk2bv    1/1     Running   0          22s

# kubectl diff exits 0 with no output when the live objects match the fixed manifests
# (ignoring the restartedAt annotation added by rollout restart)
$ kubectl diff -f fixed/ | grep -E '^[-+] ' | grep -v restartedAt || echo 'no functional differences'
no functional differences

```
