# Kubernetes Object Comparison

Three comparisons that come up constantly in interviews and in day-to-day
cluster work.

## Deployment vs ReplicaSet

| | ReplicaSet | Deployment |
| --- | --- | --- |
| Purpose | Keep N identical Pods alive | Manage ReplicaSets to deliver versioned, updatable applications |
| Pod management | Creates and deletes Pods to match `replicas` | Never touches Pods directly; it creates ReplicaSets that do |
| Scaling | `kubectl scale rs/<name> --replicas=N` | `kubectl scale deploy/<name> --replicas=N`, which is passed down to the active ReplicaSet |
| Rolling updates | Not supported — changing the Pod template does **not** replace running Pods | Supported, with `maxSurge` / `maxUnavailable`, pause, resume, and rollback |
| Revision history | None | Keeps `revisionHistoryLimit` old ReplicaSets so `kubectl rollout undo` works |
| What you write | Rarely written by hand | The normal choice for a stateless application |

**Purpose.** A ReplicaSet answers one question: *are N copies of this exact Pod
template running?* If a Pod dies, is evicted, or its node disappears, the
ReplicaSet creates a replacement. That is the whole job.

**Pod management.** The ReplicaSet owns its Pods through `metadata.ownerReferences`.
Deleting the ReplicaSet garbage-collects the Pods. A Deployment sits one level
higher and owns ReplicaSets, which in turn own Pods.

**Scaling.** Both scale, but scaling a Deployment is safer because the
Deployment remembers the desired count across updates. Scaling a ReplicaSet
that is owned by a Deployment is pointless — the Deployment controller will
reconcile the count straight back.

**Rolling updates.** This is the real reason Deployments exist. Edit the image
in a bare ReplicaSet and nothing happens to the running Pods; the new template
is only used for Pods created *after* the edit. A Deployment reacts to a
template change by creating a brand-new ReplicaSet and shifting replicas from
the old one to the new one a few at a time.

**Relationship.** One Deployment owns many ReplicaSets — one per revision:

```text
Deployment  nginx
   ├── ReplicaSet nginx-7d9fc8b6c5   (revision 2, image 1.26)  replicas: 3
   └── ReplicaSet nginx-5c8b9f7d44   (revision 1, image 1.25)  replicas: 0
```

The old ReplicaSet is scaled to zero rather than deleted. That retained,
scaled-to-zero object *is* the rollback mechanism: `kubectl rollout undo`
simply scales it back up and scales the new one down.

## Deployment vs DaemonSet vs StatefulSet

| | Deployment | DaemonSet | StatefulSet |
| --- | --- | --- | --- |
| Use case | Stateless, interchangeable replicas | One Pod per node — agents and daemons | Stateful apps needing stable identity and storage |
| Pod creation | Any number of Pods on any node the scheduler picks | Exactly one Pod per matching node, automatically added when a node joins | Ordered creation `0, 1, 2 …`, each waiting for the previous to be Ready |
| Pod names | Random suffix: `web-7d9fc8b6c5-x4k2p` | Node-derived suffix: `fluentd-abc12` | Stable ordinal: `mysql-0`, `mysql-1`, `mysql-2` |
| Scaling | `replicas` field, any count | Not scaled by you — count equals the number of eligible nodes | `replicas` field, but scaled up and down strictly in order |
| Networking | One Service load-balances across all Pods | Usually accessed on the local node, often via `hostPort` or host network | Headless Service gives each Pod its own DNS record |
| Storage | Usually none, or one shared volume | Typically `hostPath` to read node-level data | `volumeClaimTemplates` creates a **separate** PVC per Pod, retained across restarts |
| Deletion | Pods deleted in any order | Pod removed when the node leaves | Deleted in reverse ordinal order |
| Examples | Web frontends, REST APIs, workers | Log shippers (Fluent Bit), node exporters, CNI agents, `kube-proxy` | MySQL, PostgreSQL, MongoDB, Kafka, Elasticsearch, ZooKeeper |

The dividing question is *"are my Pods interchangeable?"* If yes, use a
Deployment. If each Pod must be reachable as a distinct, named member with its
own disk that survives a restart, use a StatefulSet. If the workload is really
a property of the node rather than of the application, use a DaemonSet.

## ReplicaSet vs Service

These are often confused because both "deal with a group of Pods", but they
solve opposite halves of the problem.

| | ReplicaSet | Service |
| --- | --- | --- |
| Responsibility | **Lifecycle** — making sure the Pods exist | **Connectivity** — making sure the Pods can be reached |
| Watches | Pod count against `replicas` | Pod readiness and IPs against a label selector |
| Produces | Running Pods | A stable virtual IP and DNS name |
| If it is missing | Pods are never created or replaced | Pods run but have no reliable address |

**Why a Service is required.** Pod IPs are ephemeral. Every time a ReplicaSet
replaces a Pod — a crash, a node drain, a rolling update — the replacement
gets a *new* IP. A client that cached the old IP is now talking to nothing.
The Service solves this by publishing one `ClusterIP` and one DNS name that
never change for the life of the Service, regardless of how many times the
Pods behind it are recreated.

**How traffic reaches the Pods:**

```text
client Pod
   │  resolves  backend.default.svc.cluster.local  via CoreDNS
   ▼
ClusterIP  10.96.84.17:80          ← stable, never changes
   │  kube-proxy (iptables / IPVS) DNATs to a random healthy endpoint
   ▼
EndpointSlice  [10.244.1.7:8080, 10.244.2.4:8080, 10.244.1.9:8080]
   ▼
Pods managed by the ReplicaSet
```

1. The Service's `selector` is matched against Pod labels continuously.
2. Every Pod that matches **and passes its readiness probe** is written into an
   EndpointSlice. A Pod that fails readiness is removed from the list, so
   traffic stops going to it without the Pod being killed.
3. `kube-proxy` on each node programs iptables or IPVS rules that rewrite the
   destination from the ClusterIP to one of those endpoint IPs.
4. CoreDNS resolves the Service name to the ClusterIP, so clients only ever
   need the name.

The two objects are complementary: the ReplicaSet guarantees Pods *exist*, the
Service guarantees they are *addressable*. Neither can substitute for the other.
