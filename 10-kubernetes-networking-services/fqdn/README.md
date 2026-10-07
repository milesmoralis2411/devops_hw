# FQDN in Kubernetes

## What is an FQDN?

A **Fully Qualified Domain Name** is a domain name that specifies a host's
exact location in the DNS hierarchy, all the way up to the root. It leaves
nothing to be inferred from context.

```text
backend.production.svc.cluster.local.
│       │          │   │             │
│       │          │   │             └── root zone (the trailing dot)
│       │          │   └──────────────── cluster domain
│       │          └──────────────────── resource type: svc
│       └─────────────────────────────── namespace
└─────────────────────────────────────── Service name
```

A *partially* qualified name like `backend` only works because the resolver
appends a search domain to it. The FQDN works from anywhere in the cluster.

## Kubernetes Service DNS

When a Service is created, the cluster DNS server (CoreDNS) automatically
creates records for it. Nothing has to be registered by hand.

| Service type | Record created | Resolves to |
| --- | --- | --- |
| ClusterIP | `A` / `AAAA` | The Service's stable virtual IP |
| Headless (`clusterIP: None`) | `A` / `AAAA` | The IP of **every** ready Pod, one record per Pod |
| ExternalName | `CNAME` | The external DNS name in `spec.externalName` |
| Named port on any Service | `SRV` | `_<port>._<proto>.<service>.<ns>.svc.cluster.local` |

## Naming convention

The general form for a Service is:

```text
<service-name>.<namespace>.svc.<cluster-domain>
```

`cluster-domain` defaults to `cluster.local`. For an individual Pod behind a
headless Service, each Pod also gets its own name:

```text
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

This is what makes StatefulSets useful — `mysql-0.mysql.default.svc.cluster.local`
always points at the same member, even after it is rescheduled onto a
different node with a different IP.

## Namespace-based DNS and the search path

Every Pod gets an `/etc/resolv.conf` written by the kubelet. For a Pod in the
`default` namespace it looks like this:

```text
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

The `search` list is what lets short names work, and it explains the rules
people memorise:

| You write | Resolver tries | Works when |
| --- | --- | --- |
| `backend` | `backend.default.svc.cluster.local` first | The Service is in **your own** namespace |
| `backend.production` | `backend.production.svc.cluster.local` | The Service is in the `production` namespace |
| `backend.production.svc.cluster.local` | Used as-is | Always |

So a Pod in `default` can reach a Service in `default` by its bare name, but
must qualify with the namespace to reach one anywhere else. This is name
resolution convenience only — it is **not** a security boundary. Namespaces do
not block traffic by default; NetworkPolicies do that.

`options ndots:5` means any name containing fewer than five dots is tried
against the search list *before* being tried as an absolute name. That is why
`google.com` (one dot) generates several failed cluster lookups before the
real one succeeds, and why appending a trailing dot — `google.com.` — is a
common latency fix.

## Pod-to-Service communication

```text
frontend Pod (ns: default)
   │ 1. connect to  backend
   ▼
/etc/resolv.conf  →  search default.svc.cluster.local …
   │ 2. query  backend.default.svc.cluster.local
   ▼
CoreDNS  10.96.0.10
   │ 3. answer: 10.96.84.17   (the ClusterIP)
   ▼
kube-proxy iptables/IPVS rules on the node
   │ 4. DNAT to one ready endpoint
   ▼
backend Pod  10.244.2.4:8080
```

The frontend never learns a Pod IP and never needs to. Pods can be replaced
underneath it indefinitely.

## Examples

```bash
# Same namespace — short name is enough
curl http://backend:8080

# Different namespace
curl http://backend.production:8080

# Fully qualified, works from any namespace
curl http://backend.production.svc.cluster.local:8080

# A specific StatefulSet member behind a headless Service
curl http://mysql-0.mysql.default.svc.cluster.local:3306

# The cluster's own DNS service
dig kube-dns.kube-system.svc.cluster.local

# The Kubernetes API Service, always at this name
curl -k https://kubernetes.default.svc.cluster.local/healthz

# SRV record for a named port
dig SRV _http._tcp.backend.default.svc.cluster.local
```

Verify any of these from inside the cluster:

```bash
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- \
  nslookup backend.default.svc.cluster.local
```

## Verified on the cluster

Run live on minikube — full output in [../DNS-EVIDENCE.md](../DNS-EVIDENCE.md).
A `backend` Service in namespace `production`, queried from a Pod in
`default`:

```text
$ kubectl exec dnsclient -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

$ kubectl exec dnsclient -- getent hosts backend                      # short name
command terminated with exit code 2                                    # not in "default"

$ kubectl exec dnsclient -- getent hosts backend.production            # + namespace
10.106.39.63   backend.production.svc.cluster.local

$ kubectl exec dnsclient -- getent hosts backend.production.svc.cluster.local   # FQDN
10.106.39.63   backend.production.svc.cluster.local

$ kubectl exec dnsclient -- curl -s http://backend.production | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>
```

Exactly the rules in the table above: the short name only works inside its own
namespace, `<service>.<namespace>` works from anywhere via the search path, and
the FQDN always works.

> **Gotcha found while testing:** BusyBox `nslookup backend.production` reports
> `NXDOMAIN`, even though the name resolves. BusyBox's `nslookup` does not apply
> the search list to names that already contain a dot, whereas the real system
> resolver (`getent`, `curl`, and your application) does. Test DNS with the
> same resolver your application uses.
