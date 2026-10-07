# Kubernetes Networking and Services

This lab demonstrates the five Kubernetes Service patterns.

| Service type | Scope | Main purpose |
| --- | --- | --- |
| ClusterIP | Internal cluster network | Stable access to a group of Pods |
| NodePort | Node IP and fixed port | Simple external access for local or bare-metal clusters |
| LoadBalancer | External load balancer | Public application access in cloud environments |
| ExternalName | DNS alias only | Internal name for an external service |
| Headless Service | Direct Pod DNS | Discovery of individual Pods in stateful workloads |

## 1. ClusterIP

ClusterIP is the default Kubernetes Service. It gives internal clients one
stable IP address and DNS name while routing requests to the three matching
NGINX Pods. The individual Pod IPs can change without affecting clients.

![ClusterIP Service, endpoints, and internal client response](01-clusterip/clusterip-service_24bcs10326.png)

## 2. NodePort

NodePort exposes the application through port `30080` on every cluster node.
It also creates an internal ClusterIP, so the Service can be reached from both
inside and outside the cluster.

![NodePort Service and running Pods](02-nodeport/nodeport-service_24bcs10326.png)

![NGINX application reached through NodePort](02-nodeport/nodeport-browser_24bcs10326.png)

## 3. LoadBalancer

LoadBalancer is intended for cloud environments. Kubernetes requests an
external load balancer from the cloud provider, which forwards public traffic
to the three NGINX Pods. On a local Minikube cluster, it may remain pending
until a tunnel or load-balancer addon is used.

![LoadBalancer Service created with three running Pods](03-loadbalancer/loadbalancer-service_24bcs10326.png)

![NGINX application reached through the local LoadBalancer endpoint](03-loadbalancer/loadbalancer-browser_24bcs10326.png)

![LoadBalancer external IP assigned by Minikube tunnel](03-loadbalancer/loadbalancer-external-ip_24bcs10326.png)

## 4. ExternalName

ExternalName does not select Pods or create a virtual IP. Instead, it maps the
internal DNS name `external-database-service` to `api.github.com`, allowing
applications to use a stable in-cluster alias for an external service.

![Response from the ExternalName target API](04-externalname/externalname-service_24bcs10326.png)

## 5. Headless Service

A Headless Service uses `clusterIP: None`, so it does not load-balance through
a virtual IP. Its DNS response contains the addresses of the individual Pods
in the StatefulSet, allowing clients to reach a specific Pod directly.

![Headless Service DNS results and direct Pod response](05-headless/headless-service_24bcs10326.png)

## Task 2 — Kubernetes object comparison

[comparisons/README.md](comparisons/README.md) covers Deployment vs
ReplicaSet, Deployment vs DaemonSet vs StatefulSet, and ReplicaSet vs Service.

## Task 3 — FQDN

[fqdn/README.md](fqdn/README.md) covers what an FQDN is, Service DNS records,
the naming convention, namespace-based resolution and Pod-to-Service traffic.
It includes live verification on the cluster.

## Task 4 — CoreDNS

[coredns/README.md](coredns/README.md) covers what CoreDNS is, why Kubernetes
uses it, service discovery, query resolution, the Corefile, and a
troubleshooting playbook. It also shows the live Corefile and query log.

The raw DNS output for Tasks 3 and 4 is in [DNS-EVIDENCE.md](DNS-EVIDENCE.md).

## Takeaway

Use ClusterIP for internal applications, NodePort for simple node-level exposure,
LoadBalancer for public cloud traffic, ExternalName for external DNS aliases, and 
Headless Services for stateful workloads that need direct Pod discovery.
