# Session 14 — Kubernetes Troubleshooting

| Task | Folder | What is in it |
| --- | --- | --- |
| 1. Troubleshooting commands | [01-commands/](01-commands/) | `get`, `describe`, `logs`, `exec`, `events`, `explain`, `top`, `get -o wide`, run against a live workload |
| 2. Common issues | [02-common-issues/](02-common-issues/) | Nine failure modes, each with `broken.yaml` / `fixed.yaml`, reproduced and fixed |
| 3. Mini project | [03-mini-project/](03-mini-project/) | A two-tier shop with five layered bugs, debugged end to end |

Every scenario was run on minikube v1.39.0 / Kubernetes v1.37.0. Each folder
has an `EVIDENCE.md` with the verbatim output.

## The method

```text
1. Identify      kubectl get <kind>               what state is it in?
2. Investigate   kubectl describe / logs / exec   events, application output, the inside view
                 kubectl get endpointslices       is traffic actually routable?
3. Root cause    one sentence: "X because Y"
4. Fix           change the manifest (the source of truth), then apply
5. Verify        the same commands as step 1 - plus the user-facing check (curl)
6. Document      problem, investigation, root cause, fix, before/after
```

## Where to look, by symptom

| Status / symptom | First command | Usual causes |
| --- | --- | --- |
| `Pending` | `describe pod` → Events | Insufficient CPU or memory, nodeSelector/affinity, taints, unbound PVC, ResourceQuota |
| `ContainerCreating` (stuck) | `describe pod` → Events | Missing Secret/ConfigMap volume, CSI attach, CNI problems |
| `ImagePullBackOff` / `ErrImagePull` | `describe pod` → Events | Wrong tag or repository, private registry without `imagePullSecrets`, rate limits |
| `CrashLoopBackOff` / `Error` with restarts | `logs` (and `logs --previous`) | Bad config, missing file or env, wrong command, failing liveness probe |
| `CreateContainerConfigError` | `describe pod` → Events | Missing ConfigMap/Secret, or a missing **key** within one |
| Running but `0/1` READY | `describe pod` → readiness events | Readiness probe path, port or timing |
| Service unreachable | `get endpointslices` | Selector/label mismatch, Pods not Ready, wrong `targetPort` |
| `NXDOMAIN` | `exec ... cat /etc/resolv.conf` | Short name across namespaces, CoreDNS down, `dnsPolicy` |
| Refused on the Pod IP | `exec ... netstat -tln` | App bound to `127.0.0.1`, wrong port |

## Findings from running these labs

These came from the live runs and were not planned in advance:

- **On Kubernetes v1.37, a crash-looping container shows `Error`, not
  `CrashLoopBackOff`,** while it waits out the back-off. The `BackOff` events and
  the restart count are the reliable signals.
- **The kubelet serialises image pulls.** Pulls of non-existent images sat in
  `Pulling` for over 10 minutes because a 164 MB image was downloading first.
  Once that finished, the same manifests failed in 2–4 seconds.
- **A missing repository and a private repository look identical** — GHCR
  returns `403` to an anonymous token request for both.
- **minikube's node advertises all 24 host CPUs**, not the `--cpus=2` limit, so
  "too large" requests had to be sized against 24.
- **BusyBox resolves `localhost` to `::1`.** Testing nginx (IPv4 only) via
  `localhost` gave a false "connection refused".
- **kindnet does not enforce NetworkPolicy.** Policies are accepted and stored
  but drop nothing. That is a real-world trap of its own.
