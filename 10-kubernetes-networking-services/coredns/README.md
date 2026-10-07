# CoreDNS

## What is CoreDNS?

CoreDNS is a DNS server written in Go, built as a chain of **plugins**. Each
query walks down the plugin chain until a plugin handles it. It is a general
purpose DNS server, but since Kubernetes 1.13 it has been the cluster's
default DNS, replacing kube-dns.

In the cluster it runs as an ordinary workload:

```bash
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc kube-dns -n kube-system      # ClusterIP is usually 10.96.0.10
```

Note the Service is still called `kube-dns` for backward compatibility, even
though the Pods behind it run CoreDNS.

## Why Kubernetes uses CoreDNS

kube-dns was three containers (`kubedns`, `dnsmasq`, `sidecar`) glued
together. CoreDNS replaced it with a single process, and the reasons it won
are practical:

| | kube-dns | CoreDNS |
| --- | --- | --- |
| Processes | 3 containers | 1 container |
| Config | Mostly fixed | A `Corefile`, editable as a ConfigMap |
| Extensibility | Hard | Plugin chain — add caching, rewriting, forwarding, metrics |
| Memory | Higher | Lower and more predictable |
| Security | `dnsmasq` had a history of CVEs | No `dnsmasq` dependency |

The decisive advantage is that the whole configuration is one ConfigMap you
can edit, so behaviour like stub domains or custom rewrites is a config
change rather than a fork.

## How Service discovery works

1. A Service is created. The API server stores it.
2. The CoreDNS `kubernetes` plugin **watches** the API server for Services,
   EndpointSlices and Pods. It does not poll and it does not keep a zone file.
3. It builds DNS answers from that live, in-memory view of cluster state.
4. A Pod queries the name; CoreDNS answers from that view.

Because it is watch-driven, a new Service is resolvable within roughly the
time it takes for the watch event to arrive — no reload, no zone transfer.

What gets answered:

| Query | Answer |
| --- | --- |
| `<svc>.<ns>.svc.cluster.local` on a ClusterIP Service | The Service virtual IP |
| the same on a **headless** Service | One A record per ready Pod |
| `<pod>.<svc>.<ns>.svc.cluster.local` | That one Pod IP |
| the same on an ExternalName Service | A CNAME to the external name |
| Anything outside the cluster domain | Forwarded upstream |

## How a DNS query is resolved

```text
app Pod
  | 1. getaddrinfo("backend")
  v
/etc/resolv.conf   nameserver 10.96.0.10
                   search default.svc.cluster.local svc.cluster.local cluster.local
                   options ndots:5
  | 2. "backend" has 0 dots, which is < ndots:5, so try the search list first:
  |    backend.default.svc.cluster.local
  v
kube-dns Service 10.96.0.10:53  -> kube-proxy DNATs to a CoreDNS Pod
  v
CoreDNS plugin chain (in Corefile order)
   errors -> health -> ready -> kubernetes -> prometheus -> forward -> cache -> loop -> reload
                        |
                        +-- name ends in cluster.local, so the kubernetes
                            plugin claims it and returns 10.96.84.17
  | 3. answer cached for the TTL (30s by default)
  v
app connects to 10.96.84.17
```

If the name had **not** matched `cluster.local` — say `github.com` — the
`kubernetes` plugin would pass, and `forward . /etc/resolv.conf` would send it
to the upstream resolver of the node.

## CoreDNS configuration

The config lives in a ConfigMap:

```bash
kubectl -n kube-system get configmap coredns -o yaml
kubectl -n kube-system edit configmap coredns     # edit it
```

A default Corefile:

```text
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

What each plugin does:

| Plugin | Role |
| --- | --- |
| `errors` | Log errors to stdout |
| `health` | `/health` endpoint for the liveness probe; `lameduck` keeps it serving briefly during shutdown |
| `ready` | `/ready` endpoint — reports healthy only once the API watches have synced |
| `kubernetes` | The cluster plugin: answers `cluster.local` and reverse lookups from watched API objects |
| `prometheus` | Exposes metrics on `:9153` |
| `forward` | Sends everything else to the upstream resolvers of the node |
| `cache` | Caches answers for 30s |
| `loop` | Detects a forwarding loop and crashes the Pod deliberately rather than melting the cluster |
| `reload` | Picks up Corefile changes automatically, no restart needed |
| `loadbalance` | Randomises A-record order across answers |

A common customisation — send one domain to a different resolver:

```text
company.internal:53 {
    errors
    cache 30
    forward . 10.0.0.53
}
```

Per-Pod overrides are also possible without touching CoreDNS at all, using
`spec.dnsConfig` and `spec.dnsPolicy` on the Pod.

## Troubleshooting DNS issues

**1. Confirm CoreDNS is actually running**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
kubectl get svc kube-dns -n kube-system
kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns
```

Empty endpoints means the Service has no healthy Pods to send to — that alone
breaks every lookup in the cluster.

**2. Test resolution from inside a Pod**

```bash
kubectl run dnsutils --image=busybox:1.36 --rm -it --restart=Never -- /bin/sh

# inside:
nslookup kubernetes.default
nslookup backend.default.svc.cluster.local
nslookup google.com                    # tests the forward path
cat /etc/resolv.conf
```

**3. Read the resolv.conf of the Pod**

If `nameserver` is not the kube-dns ClusterIP, the Pod `dnsPolicy` is wrong —
`hostNetwork: true` Pods need `dnsPolicy: ClusterFirstWithHostNet`, or they
will use the node resolver and never see cluster names.

**4. Turn on query logging**

Add the `log` plugin to the Corefile, then watch:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns -f
```

`reload` picks the change up within about 30 seconds. Remove it afterwards —
it is noisy and costs CPU.

**5. Check the Service actually has endpoints**

A name that resolves but refuses connections is usually not DNS at all:

```bash
kubectl get endpointslices -l kubernetes.io/service-name=backend
kubectl describe svc backend
```

No endpoints means the Service `selector` does not match any Pod labels, or
every Pod is failing its readiness probe.

**6. Rule out NetworkPolicy**

A policy that denies egress will block UDP/53 to CoreDNS along with
everything else. Any default-deny egress policy needs an explicit allow:

```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

**7. Watch for the ndots:5 slowdown**

External lookups are tried against all search domains first, producing several
NXDOMAIN round-trips before the real answer. If external DNS feels slow,
either use a trailing dot (`api.example.com.`) or lower `ndots` for that Pod:

```yaml
dnsConfig:
  options:
    - name: ndots
      value: "2"
```

### Quick triage table

| Symptom | Likely cause |
| --- | --- |
| Nothing in the cluster resolves | CoreDNS Pods down, or kube-dns Service has no endpoints |
| Cluster names work, internet does not | `forward` upstream unreachable from the node |
| Internet works, cluster names do not | Wrong `dnsPolicy`, or Pod is on host network |
| Resolves but connection refused | Service selector matches nothing, or readiness probes failing |
| Resolution is slow | `ndots:5` search-path overhead |
| CrashLoopBackOff with "Loop detected" | Node resolv.conf points back at CoreDNS |

## Verified on the cluster

Captured live on minikube — full output in [../DNS-EVIDENCE.md](../DNS-EVIDENCE.md).

```text
$ kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    IP           NODE
coredns-559f6c778d-zndtf   1/1     Running   10.244.0.2   minikube

$ kubectl get svc kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP   PORT(S)
kube-dns   ClusterIP   10.96.0.10   53/UDP,53/TCP,9153/TCP
```

The live Corefile on minikube matches the default above, with two additions: a
`log` plugin (query logging is on), and a `hosts` block that maps
`host.minikube.internal` to the host machine.

**The `ndots:5` search-path cost, seen in the CoreDNS query log.** One lookup of
`backend.production.svc.cluster.local` — a name with 4 dots, which is fewer
than 5 — was first tried with every search domain appended, and only then as
an absolute name:

```text
"A IN backend.production.svc.cluster.local.default.svc.cluster.local." NXDOMAIN
"A IN backend.production.svc.cluster.local.svc.cluster.local."         NXDOMAIN
"A IN backend.production.svc.cluster.local.cluster.local."             NXDOMAIN
"A IN backend.production.svc.cluster.local."                           NOERROR
```

That is 3 wasted round trips (6 counting AAAA) for every lookup. Appending a
trailing dot (`backend.production.svc.cluster.local.`) or lowering `ndots`
removes them.
