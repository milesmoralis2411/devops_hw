# Evidence — Ingress / ConfigMap / Secret troubleshooting

Executed on minikube v1.39.0 / Kubernetes v1.37.0 with the ingress-nginx addon, 2026-10-07. Output is verbatim.

## Case 01 - Pod references a missing ConfigMap
```text
# BEFORE
$ kubectl apply -f 01-missing-configmap/broken.yaml
pod/ts-missing-configmap created

$ kubectl get pod ts-missing-configmap
NAME                   READY   STATUS                       RESTARTS   AGE
ts-missing-configmap   0/1     CreateContainerConfigError   0          11s

$ kubectl describe pod ts-missing-configmap | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  11s                default-scheduler  Successfully assigned default/ts-missing-configmap to minikube
  Normal   Pulled     10s (x2 over 10s)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Warning  Failed     10s (x2 over 10s)  kubelet            spec.containers{app}: Error: configmap "app-config" not found

# FIX
$ kubectl apply -f 01-missing-configmap/fixed.yaml
configmap/app-config created
pod/ts-missing-configmap-fixed created

$ kubectl wait --for=condition=Ready pod/ts-missing-configmap-fixed --timeout=120s
pod/ts-missing-configmap-fixed condition met

# AFTER
$ kubectl get pod ts-missing-configmap ts-missing-configmap-fixed
NAME                         READY   STATUS                       RESTARTS   AGE
ts-missing-configmap         0/1     CreateContainerConfigError   0          12s
ts-missing-configmap-fixed   1/1     Running                      0          1s

$ kubectl logs ts-missing-configmap-fixed
APP_ENV=production

# the original Pod recovers by itself once the ConfigMap exists
$ kubectl get pod ts-missing-configmap
NAME                   READY   STATUS    RESTARTS   AGE
ts-missing-configmap   1/1     Running   0          28s

```

## Case 02 - Secret exists, but the key name is wrong
```text
# BEFORE
$ kubectl apply -f 02-missing-secret-key/broken.yaml
secret/db-secret created
pod/ts-missing-secret-key created

$ kubectl get pod ts-missing-secret-key
NAME                    READY   STATUS                       RESTARTS   AGE
ts-missing-secret-key   0/1     CreateContainerConfigError   0          10s

$ kubectl describe pod ts-missing-secret-key | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  11s                default-scheduler  Successfully assigned default/ts-missing-secret-key to minikube
  Normal   Pulled     10s (x2 over 10s)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Warning  Failed     10s (x2 over 10s)  kubelet            spec.containers{app}: Error: couldn't find key db_pass in Secret default/db-secret

$ kubectl get secret db-secret -o jsonpath='{.data}' | tr ',' '\n' | sed 's/:.*//'
{"db_password"
"db_user"
# FIX
$ kubectl apply -f 02-missing-secret-key/fixed.yaml
secret/db-secret configured
pod/ts-missing-secret-key-fixed created

$ kubectl wait --for=condition=Ready pod/ts-missing-secret-key-fixed --timeout=120s
pod/ts-missing-secret-key-fixed condition met

# AFTER
$ kubectl get pod ts-missing-secret-key ts-missing-secret-key-fixed
NAME                          READY   STATUS                       RESTARTS   AGE
ts-missing-secret-key         0/1     CreateContainerConfigError   0          12s
ts-missing-secret-key-fixed   1/1     Running                      0          1s

$ kubectl logs ts-missing-secret-key-fixed
user=appuser

$ kubectl exec ts-missing-secret-key-fixed -- sh -c 'echo DB_PASS is ${#DB_PASS} characters long'
DB_PASS is 16 characters long

```

## Case 03 - Ingress points at a Service name that does not exist
```text
# BEFORE
$ kubectl apply -f 03-ingress-404/broken.yaml
deployment.apps/ts-web created
service/web-service created
ingress.networking.k8s.io/ts-ingress-404 created

$ kubectl rollout status deploy/ts-web --timeout=180s
Waiting for deployment "ts-web" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "ts-web" rollout to finish: 1 of 2 updated replicas are available...
deployment "ts-web" successfully rolled out

$ kubectl get ingress ts-ingress-404
NAME             CLASS   HOSTS           ADDRESS   PORTS   AGE
ts-ingress-404   nginx   ts-demo.local             80      21s

$ kubectl describe ingress ts-ingress-404 | sed -n '/Rules:/,/Annotations:/p'
Rules:
  Host           Path  Backends
  ----           ----  --------
  ts-demo.local  
                 /   web-svc:80 (<error: services "web-svc" not found>)
Annotations:     <none>

$ curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H 'Host: ts-demo.local' http://192.168.49.2/ --max-time 5 || minikube ssh -- curl -s -o /dev/null -w 'HTTP_%{http_code}' -H 'Host:ts-demo.local' http://localhost/
HTTP 000
HTTP_503
$ kubectl get svc web-svc web-service
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
web-service   ClusterIP   10.103.83.160   <none>        80/TCP    28s
Error from server (NotFound): services "web-svc" not found

# FIX
$ kubectl delete ingress ts-ingress-404
ingress.networking.k8s.io "ts-ingress-404" deleted from default namespace

$ kubectl apply -f 03-ingress-404/fixed.yaml
deployment.apps/ts-web unchanged
service/web-service unchanged
ingress.networking.k8s.io/ts-ingress-fixed created

# AFTER
$ kubectl get ingress ts-ingress-fixed
NAME               CLASS   HOSTS           ADDRESS        PORTS   AGE
ts-ingress-fixed   nginx   ts-demo.local   192.168.49.2   80      25s

$ minikube ssh -- curl -s -H 'Host:ts-demo.local' http://localhost/ | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>

```

## Case 04 - Ingress names an IngressClass no controller implements
```text
# BEFORE
$ kubectl apply -f 04-ingress-wrong-class/broken.yaml
ingress.networking.k8s.io/ts-ingress-wrongclass created

$ kubectl get ingress ts-ingress-wrongclass
NAME                    CLASS     HOSTS              ADDRESS   PORTS   AGE
ts-ingress-wrongclass   traefik   wrongclass.local             80      30s

$ minikube ssh -- curl -s -o /dev/null -w 'HTTP_%{http_code}' -H 'Host:wrongclass.local' http://localhost/
HTTP_404

# INVESTIGATE
$ kubectl get ingressclass
NAME              CONTROLLER             PARAMETERS   AGE
nginx (default)   k8s.io/ingress-nginx   <none>       39m

$ kubectl get ingress ts-ingress-wrongclass -o jsonpath='ingressClassName={.spec.ingressClassName}'; echo
ingressClassName=traefik

$ kubectl describe ingress ts-ingress-wrongclass | sed -n '/^Events:/,$p'
Events:             <none>

$ kubectl get deploy -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep -iE 'class|watch'
"--controller-class=k8s.io/ingress-nginx"
"--watch-ingress-without-class=true"

# ROOT CAUSE: the only controller implements class 'nginx' (k8s.io/ingress-nginx).
# Nothing implements 'traefik', so no controller claims the Ingress: no ADDRESS, 404.
# FIX
$ kubectl apply -f 04-ingress-wrong-class/fixed.yaml
ingress.networking.k8s.io/ts-ingress-wrongclass configured

# AFTER
$ kubectl get ingress ts-ingress-wrongclass
NAME                    CLASS   HOSTS              ADDRESS   PORTS   AGE
ts-ingress-wrongclass   nginx   wrongclass.local             80      62s

$ minikube ssh -- curl -s -H 'Host:wrongclass.local' http://localhost/ | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>

```

## Note - why an Ingress with NO class still works on minikube
```text
$ kubectl get ingressclass nginx -o jsonpath='{.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class}'; echo
true

# 1) nginx is the default IngressClass, and 2) the controller runs with
# --watch-ingress-without-class=true (see the args above). Both safety nets were
# confirmed while testing: a class-less Ingress was adopted and served HTTP 200.
```
