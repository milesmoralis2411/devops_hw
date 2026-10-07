# Pod Lifecycle

Each YAML file in this folder puts a Pod into one specific lifecycle state. Each
one was applied, its status and details were checked, and the output was
captured. The full verbatim output is in [EVIDENCE.md](EVIDENCE.md).

## The model

A Pod has a single high-level **phase**, and each container inside it has its
own **state**:

```text
Pod phase:        Pending ──► Running ──► Succeeded
                                     └──► Failed
                  (Unknown: the node stopped reporting)

Container state:  Waiting ──► Running ──► Terminated
                     ▲                        │
                     └──── restartPolicy ─────┘
```

| Pod phase | Meaning |
| --- | --- |
| `Pending` | Accepted by the API server, but not all containers are running yet — still scheduling, pulling images or running init containers |
| `Running` | Bound to a node, at least one container is running or restarting |
| `Succeeded` | All containers exited 0 and will not be restarted |
| `Failed` | All containers have terminated and at least one exited non-zero |
| `Unknown` | The node is unreachable, so the state cannot be read |

Words such as `CrashLoopBackOff`, `ImagePullBackOff`, `Completed` and
`Init:0/2` in the `STATUS` column are **not** phases. They are container
state reasons that `kubectl` shows for convenience.

| # | File | Demonstrates |
| --- | --- | --- |
| 01 | [01-pending.yaml](01-pending.yaml) | Unschedulable Pod — `Pending` |
| 02 | [02-running.yaml](02-running.yaml) | Normal start-up — `Running` |
| 03 | [03-succeeded.yaml](03-succeeded.yaml) | Exit 0, `restartPolicy: Never` — `Succeeded` |
| 04 | [04-failed.yaml](04-failed.yaml) | Exit 1, `restartPolicy: Never` — `Failed` |
| 05 | [05-crashloopbackoff.yaml](05-crashloopbackoff.yaml) | Exit 1, `restartPolicy: Always` — restart with back-off |
| 06 | [06-init-containers.yaml](06-init-containers.yaml) | Init containers run before the app |
| 07 | [07-lifecycle-hooks.yaml](07-lifecycle-hooks.yaml) | `postStart` and `preStop` hooks |
| 08 | [08-probes.yaml](08-probes.yaml) | Startup, readiness and liveness probes |

```bash
# For each file
kubectl apply -f 01-pending.yaml          # 1. apply
kubectl get pod lifecycle-pending -o wide  # 2. status
kubectl describe pod lifecycle-pending     # 3. details + events
```

## 01 — Pending

```text
NAME                READY   STATUS    RESTARTS   AGE   IP       NODE
lifecycle-pending   0/1     Pending   0          8s    <none>   <none>

Conditions:
  PodScheduled   False
Events:
  Warning  FailedScheduling  default-scheduler  0/1 nodes are available:
           1 Insufficient cpu, 1 Insufficient memory.
```

**Observed:** the Pod was accepted but never got a node or an IP.
`PodScheduled=False`, and the scheduler explained why: it requested 100 CPUs
and 256 Gi, and the only node has 24 CPUs and about 7.6 Gi. A Pod stays `Pending` indefinitely
until something changes — a smaller request, or a new node.

## 02 — Running

```text
NAME                READY   STATUS    RESTARTS   IP            NODE
lifecycle-running   1/1     Running   0          10.244.0.69   minikube

PodReadyToStartContainers=True
Initialized=True
Ready=True
ContainersReady=True
PodScheduled=True

Events:  Scheduled -> Pulled -> Created -> Started
```

**Observed:** the happy path. The events show the exact sequence — the
scheduler assigns the Pod to a node, then the kubelet pulls the image, creates
the container and starts it. All five Pod conditions become `True`, in order.

## 03 — Succeeded

```text
NAME                  READY   STATUS      RESTARTS
lifecycle-succeeded   0/1     Completed   0

phase=Succeeded exitCode=0 reason=Completed
```

**Observed:** the container printed `doing work` / `done`, then exited 0.
Because `restartPolicy: Never`, nothing restarted it, so the Pod reached the
terminal phase `Succeeded`. `kubectl` shows this as `Completed`. This is how
Job Pods finish.

## 04 — Failed

```text
NAME               READY   STATUS   RESTARTS
lifecycle-failed   0/1     Error    0

phase=Failed exitCode=1 reason=Error
```

**Observed:** the same kind of Pod, but it exits 1. With no restarts allowed,
it ends in the terminal phase `Failed`. The exit code is preserved in the
container status and the logs remain readable — the first two things to check
when a batch job fails.

## 05 — Restart with back-off (CrashLoopBackOff)

```text
t+ 10s  lifecycle-crashloop   0/1   Error   1 (6s ago)
t+ 30s  lifecycle-crashloop   0/1   Error   2 (23s ago)
t+ 60s  lifecycle-crashloop   0/1   Error   3 (37s ago)

phase=Running restarts=3 state={"terminated":{"exitCode":1,"reason":"Error",...}}
Warning  BackOff  kubelet  Back-off restarting failed container worker
```

**Observed:** the command is the same as in 04, but with
`restartPolicy: Always`. The kubelet keeps restarting the container, and the
gap between restarts grows (10s, 20s, 40s … up to a 5-minute cap). That
growing delay is the back-off. Two details stand out:

- The Pod **phase stays `Running`** throughout, even though the app never
  works. That is why phase alone is a poor health signal.
- On this cluster (Kubernetes v1.37) the container is reported as
  `terminated / Error` while it waits out the back-off, so `STATUS` shows
  `Error`. Older versions report it as `waiting / CrashLoopBackOff`. Either
  way, the `BackOff` events and the climbing `RESTARTS` count are what
  identify the loop. `kubectl logs` showed the crashed run's output
  (`starting`).

## 06 — Init containers

```text
lifecycle-init   0/1   Init:0/2   0     0s
lifecycle-init   0/1   Init:0/2   0     16s     <- init-wait sleeping 15s
lifecycle-init   1/1   Running    0     21s     <- both init containers done

init-wait: Completed (exit 0)
init-seed: Completed (exit 0)

$ kubectl exec lifecycle-init -c app -- cat /usr/share/nginx/html/index.html
<h1>seeded by init container</h1>
```

**Observed:** the Pod sat in `Init:0/2` for the 15 seconds that the first init
container slept. The app container did not start at all until **both** init
containers had exited successfully, in order. The page nginx served was
written by `init-seed` into a shared `emptyDir`, which is the standard pattern
for "prepare something, then start the app".

## 07 — Lifecycle hooks

```text
$ kubectl exec lifecycle-hooks -- cat /usr/share/nginx/html/hook.txt
postStart hook ran at Wed Oct  7 15:15:38 UTC 2026

$ kubectl delete pod lifecycle-hooks
deletion took 11s
```

**Observed:** the `postStart` hook ran as soon as the container was created
and wrote the file. On delete, the `preStop` hook ran *before* SIGTERM was
sent: it slept 10 seconds, then stopped nginx gracefully, so deletion took
11s instead of about 1s. This is how applications drain in-flight requests
before shutting down.

## 08 — Probes

```text
Liveness:   http-get http://:80/ delay=10s timeout=1s period=10s #success=1 #failure=3
Readiness:  http-get http://:80/ delay=2s  timeout=1s period=5s  #success=1 #failure=3
Startup:    http-get http://:80/ delay=0s  timeout=1s period=2s  #success=1 #failure=30

Ready=True  ContainersReady=True
```

**Observed:** the startup probe passed first, which enabled the readiness and
liveness probes. Readiness then marked the Pod `Ready`. Probe *failures* —
restarts from liveness, endpoint removal from readiness — are demonstrated in
[Session 13](../../12-kubernetes-storage-hpa-probes/03-probes/).

## All phases side by side

```text
NAME                  READY   STATUS      RESTARTS
lifecycle-crashloop   0/1     Error       5 (101s ago)    phase Running
lifecycle-failed      0/1     Error       0               phase Failed
lifecycle-init        1/1     Running     0               phase Running
lifecycle-pending     0/1     Pending     0               phase Pending
lifecycle-probes      1/1     Running     0               phase Running
lifecycle-running     1/1     Running     0               phase Running
lifecycle-succeeded   0/1     Completed   0               phase Succeeded
```

Note the two `Error` rows: one is the terminal phase `Failed`, the other is a
`Running` Pod in a restart loop. Only the `PHASE` field or the restart count
tells them apart.
