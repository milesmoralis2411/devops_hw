# Troubleshooting — ConfigMaps, Secrets and Ingress

Four broken scenarios, each with a `broken.yaml` and a `fixed.yaml`. Each one
was reproduced on minikube, investigated, root-caused, fixed and verified. The
before/after output below is excerpted from [EVIDENCE.md](EVIDENCE.md), which
has the full unedited run.

| # | Scenario | Symptom | Root cause |
| --- | --- | --- | --- |
| 01 | [missing-configmap](01-missing-configmap/) | `CreateContainerConfigError` | `configMapKeyRef` names a ConfigMap that does not exist |
| 02 | [missing-secret-key](02-missing-secret-key/) | `CreateContainerConfigError` | The Secret exists, but the key is `db_password`, not `db_pass` |
| 03 | [ingress-404](03-ingress-404/) | HTTP 503 through the Ingress | The backend names Service `web-svc`; the real one is `web-service` |
| 04 | [ingress-wrong-class](04-ingress-wrong-class/) | No `ADDRESS`, HTTP 404 | `ingressClassName: traefik` — no controller implements it |

## The method, every time

```bash
kubectl get pod <pod>                       # 1. identify   - what state is it in?
kubectl describe pod <pod>                  # 2. investigate - read the Events
kubectl get configmap,secret,svc,ingress    #    check the objects it references
kubectl logs <pod>                          #    what the app itself says
# 3. root cause  4. fix (apply the corrected manifest)  5. verify (same commands again)
```

## 01 — Pod references a missing ConfigMap

**Before**

```text
$ kubectl get pod ts-missing-configmap
NAME                   READY   STATUS                       RESTARTS   AGE
ts-missing-configmap   0/1     CreateContainerConfigError   0          11s

$ kubectl describe pod ts-missing-configmap
  Warning  Failed  kubelet  Error: configmap "app-config" not found
```

**Root cause:** the kubelet resolves environment variables *before* starting
the container. A missing ConfigMap means the container cannot be created at
all, so there are no logs to read — the answer is only in the Events.

**Fix:** create the ConfigMap (`fixed.yaml`).

**After**

```text
ts-missing-configmap-fixed   1/1     Running   0     1s
$ kubectl logs ts-missing-configmap-fixed
APP_ENV=production

# and the ORIGINAL Pod recovered on its own, with no restart needed:
ts-missing-configmap         1/1     Running   0     28s
```

The kubelet keeps retrying, so once the reference resolves the stuck Pod
starts by itself.

## 02 — Secret exists, but the key name is wrong

**Before**

```text
ts-missing-secret-key   0/1   CreateContainerConfigError   0   10s

Warning  Failed  kubelet  Error: couldn't find key db_pass in Secret default/db-secret

$ kubectl get secret db-secret -o jsonpath='{.data}' | tr ',' '\n' | sed 's/:.*//'
{"db_password"
"db_user"
```

**Root cause:** `secretKeyRef.key: db_pass`, but the Secret's key is
`db_password`. Listing only the key *names* confirms this without ever
printing the secret values — the safe way to debug Secrets.

**Fix:** reference the correct key.

**After**

```text
ts-missing-secret-key-fixed   1/1   Running   0   1s
$ kubectl logs ts-missing-secret-key-fixed
user=appuser
$ kubectl exec ts-missing-secret-key-fixed -- sh -c 'echo DB_PASS is ${#DB_PASS} characters long'
DB_PASS is 16 characters long
```

The password was verified by its *length*, never by printing it.

## 03 — Ingress points at a Service that does not exist

**Before**

```text
$ kubectl get ingress ts-ingress-404
NAME             CLASS   HOSTS           ADDRESS   PORTS
ts-ingress-404   nginx   ts-demo.local             80

$ kubectl describe ingress ts-ingress-404
  ts-demo.local  /   web-svc:80 (<error: services "web-svc" not found>)

$ curl -H 'Host: ts-demo.local' http://localhost/      # from inside the minikube node
HTTP_503

$ kubectl get svc web-svc web-service
web-service   ClusterIP   10.103.83.160   80/TCP
Error from server (NotFound): services "web-svc" not found
```

**Root cause:** the API server does not validate that an Ingress backend
exists, so the typo was accepted. The controller had a route but no
endpoints, so it answered `503 Service Temporarily Unavailable`.
`kubectl describe ingress` states the error explicitly.

**Fix:** point the backend at `web-service`.

**After**

```text
ts-ingress-fixed   nginx   ts-demo.local   192.168.49.2   80
$ curl -H 'Host: ts-demo.local' http://localhost/ | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>
```

## 04 — Ingress names a class no controller implements

**Before**

```text
$ kubectl get ingress ts-ingress-wrongclass
NAME                    CLASS     HOSTS              ADDRESS   PORTS   AGE
ts-ingress-wrongclass   traefik   wrongclass.local             80      30s

$ curl -H 'Host: wrongclass.local' http://localhost/
HTTP_404

$ kubectl get ingressclass
nginx (default)   k8s.io/ingress-nginx

$ kubectl describe ingress ts-ingress-wrongclass
Events:  <none>
```

**Root cause:** the only installed controller implements class `nginx`.
Nothing implements `traefik`, so **no controller ever looks at this object** —
which is why there is no `ADDRESS` and not even a single Event. The
controller answers 404 because, as far as it knows, the host does not exist.

**Fix:** `ingressClassName: nginx`.

**After**

```text
ts-ingress-wrongclass   nginx   wrongclass.local   80
$ curl -H 'Host: wrongclass.local' http://localhost/ | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>
```

### A finding from testing this case

The original version of this case simply *omitted* `ingressClassName`, which is
the textbook way to break an Ingress. **On minikube it does not break.** Two
safety nets adopt class-less Ingresses, and both were confirmed:

```text
$ kubectl get ingressclass nginx -o jsonpath='{...is-default-class}'
true                                              # 1. nginx is the DEFAULT class

$ kubectl get deploy -n ingress-nginx ingress-nginx-controller -o jsonpath='{...args}'
"--watch-ingress-without-class=true"              # 2. controller adopts class-less Ingresses
```

With the default annotation temporarily removed, a class-less Ingress still
served HTTP 200, because of the second flag. On a cluster without these — for
example ingress-nginx installed with Helm defaults, or a cluster running
several controllers — omitting the class fails exactly as in case 04. The
lesson: always set `ingressClassName` explicitly rather than relying on
cluster defaults.
