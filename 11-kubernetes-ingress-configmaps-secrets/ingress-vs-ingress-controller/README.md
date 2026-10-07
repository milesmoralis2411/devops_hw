# Ingress vs Ingress Controller

The single most common Kubernetes confusion: creating an Ingress object and
wondering why nothing happens. The answer is that an Ingress on its own does
nothing at all.

## What is an Ingress?

An **Ingress** is an API object. It is a *rule* — a declarative description of
how HTTP and HTTPS traffic from outside the cluster should map onto Services
inside it. It can express:

- host-based routing (`shop.example.com` vs `api.example.com`)
- path-based routing (`/` vs `/api`)
- TLS termination (which Secret holds the certificate for which host)
- a default backend for anything unmatched

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yatri-ingress
spec:
  ingressClassName: nginx          # which controller should pick this up
  rules:
    - host: yatri.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 8080
```

Store that in etcd and you have… a row in a database. No traffic moves.

## What is an Ingress Controller?

An **Ingress Controller** is the *program* that makes the rule real. It is an
ordinary workload running in the cluster — usually a Deployment or DaemonSet —
that:

1. **Watches** the API server for Ingress, Service and EndpointSlice objects.
2. **Translates** them into the configuration format of an actual reverse
   proxy (an `nginx.conf`, an Envoy xDS config, a HAProxy config).
3. **Reloads** that proxy so it starts serving the new routes.
4. **Exposes itself** to the outside world, typically through a
   `LoadBalancer` or `NodePort` Service, so external traffic has somewhere to
   land.

Common implementations: ingress-nginx, Traefik, HAProxy Ingress, Envoy-based
controllers such as Contour and Emissary, and the cloud-native ones — AWS Load
Balancer Controller, GKE Ingress, AGIC on Azure.

```bash
# The controller is just Pods
kubectl get pods -n ingress-nginx
kubectl get svc  -n ingress-nginx
kubectl get ingressclass
```

## The difference, side by side

| | Ingress | Ingress Controller |
| --- | --- | --- |
| What it is | An API object (YAML / data) | A running program (Pods) |
| Analogy | The traffic sign | The traffic police who enforce it |
| Created by | You | Installed once, cluster-wide, usually by the platform team |
| How many | Many — typically one per application | Usually one, sometimes a few (public vs internal) |
| Lives in | Any namespace | Its own namespace, e.g. `ingress-nginx` |
| Does it handle packets? | No | Yes — every request passes through it |
| Kubernetes ships it? | Yes, the API type is built in | **No** — you must install one yourself |
| If absent | Rules exist but are inert; `ADDRESS` stays blank | Your Ingress YAML does nothing |

## Why both are required

The split exists so the **interface** is standard while the **implementation**
stays pluggable. You write one portable Ingress manifest; the cluster operator
decides whether NGINX, Traefik or an AWS ALB actually serves it. Move the app
from minikube to EKS and the YAML is unchanged — only the controller behind it
differs.

```text
                    internet
                        |
                        v
      Service type=LoadBalancer / NodePort      <- how traffic enters
                        |
                        v
          +-----------------------------+
          |   Ingress Controller Pods   |       <- the proxy doing the work
          |   (nginx / traefik / envoy) |
          +-----------------------------+
             reads   ^           |  routes to
                     |           v
            Ingress objects   ClusterIP Services
            (your rules)            |
                                    v
                              application Pods
```

The controller is the only component in that diagram that touches a packet.
The Ingress object is the only one you normally write.

## Examples

**Install a controller (minikube):**

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx -w
```

**Install a controller (any cluster, via Helm):**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

**Confirm the controller adopted your Ingress** — the `ADDRESS` column is the
tell. Blank means no controller claimed it:

```bash
$ kubectl get ingress
NAME            CLASS   HOSTS         ADDRESS        PORTS   AGE
yatri-ingress   nginx   yatri.local   192.168.49.2   80      30s
#                                     ^^^^^^^^^^^^
#                        populated => a controller is handling this rule
```

**Routing two controllers in one cluster** using `ingressClassName`:

```yaml
spec:
  ingressClassName: nginx-internal    # only the internal controller claims it
```

### The failure you will actually hit

```bash
$ kubectl get ingress
NAME            CLASS   HOSTS         ADDRESS   PORTS   AGE
yatri-ingress   nginx   yatri.local             80      5m
```

Empty `ADDRESS` after several minutes means either no controller is installed,
or none of the installed controllers matches the `ingressClassName`. Check with:

```bash
kubectl get ingressclass
kubectl describe ingress yatri-ingress
kubectl get pods -A | grep -i ingress
```

## One-line summary

> **Ingress is the rule. The Ingress Controller is the thing that obeys it.**
> Kubernetes gives you the rule format for free; you have to install something
> that reads it.
