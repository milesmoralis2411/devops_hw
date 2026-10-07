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

## Screenshots

Live output from a second run of every task on 2026-10-07. Each image also
sits next to its explanation in the task's own README.

### Task 1 — Troubleshooting commands

![kubectl get - what exists and what state is it in?](01-commands/screenshots/cmd-kubectl-get-what-exists-and-what-state-is-it-in_24bcs10326.png)

![kubectl get -o wide - add IPs and node placement](01-commands/screenshots/cmd-kubectl-get-o-wide-add-ips-and-node-placement_24bcs10326.png)

![kubectl describe - full detail plus recent events](01-commands/screenshots/cmd-kubectl-describe-full-detail-plus-recent-events_24bcs10326.png)

![kubectl logs - what did the process print?](01-commands/screenshots/cmd-kubectl-logs-what-did-the-process-print_24bcs10326.png)

![kubectl exec - look from inside the container  (1/2)](01-commands/screenshots/cmd-kubectl-exec-look-from-inside-the-container-1_24bcs10326.png)

![kubectl exec - look from inside the container  (2/2)](01-commands/screenshots/cmd-kubectl-exec-look-from-inside-the-container-2_24bcs10326.png)

![kubectl events - the cluster's own timeline](01-commands/screenshots/cmd-kubectl-events-the-cluster-s-own-timeline_24bcs10326.png)

![kubectl explain - built-in API documentation  (1/2)](01-commands/screenshots/cmd-kubectl-explain-built-in-api-documentation-1_24bcs10326.png)

![kubectl explain - built-in API documentation  (2/2)](01-commands/screenshots/cmd-kubectl-explain-built-in-api-documentation-2_24bcs10326.png)

![kubectl top - live CPU and memory (needs metrics-server)](01-commands/screenshots/cmd-kubectl-top-live-cpu-and-memory-needs-metrics-se_24bcs10326.png)

![Other everyday helpers  (1/2)](01-commands/screenshots/cmd-other-everyday-helpers-1_24bcs10326.png)

![Other everyday helpers  (2/2)](01-commands/screenshots/cmd-other-everyday-helpers-2_24bcs10326.png)

### Task 2 — Common issues (identify → investigate → root cause → fix → verify)

![01 - CrashLoopBackOff](02-common-issues/screenshots/issue-01-crashloopbackoff_24bcs10326.png)

![02 - ImagePullBackOff (tag does not exist)](02-common-issues/screenshots/issue-02-imagepullbackoff-tag-does-not-exist_24bcs10326.png)

![03 - ErrImagePull (repository does not exist)](02-common-issues/screenshots/issue-03-errimagepull-repository-does-not-exist_24bcs10326.png)

![04 - Pending](02-common-issues/screenshots/issue-04-pending_24bcs10326.png)

![05 - Stuck in ContainerCreating](02-common-issues/screenshots/issue-05-stuck-in-containercreating_24bcs10326.png)

![06 - Service connectivity](02-common-issues/screenshots/issue-06-service-connectivity_24bcs10326.png)

![07 - DNS issues](02-common-issues/screenshots/issue-07-dns-issues_24bcs10326.png)

![08 - Pod networking (server bound to loopback)](02-common-issues/screenshots/issue-08-pod-networking-server-bound-to-loopback_24bcs10326.png)

![08b - Pod networking variant: NetworkPolicy](02-common-issues/screenshots/issue-08b-pod-networking-variant-networkpolicy_24bcs10326.png)

![09 - Configuration errors](02-common-issues/screenshots/issue-09-configuration-errors_24bcs10326.png)

### Task 3 — Mini project: five layered bugs

![Deploy the broken shop](03-mini-project/screenshots/mini-deploy-the-broken-shop_24bcs10326.png)

![Bug 1 - frontend Pods stuck in Pending](03-mini-project/screenshots/mini-bug-1-frontend-pods-stuck-in-pending_24bcs10326.png)

![Bug 2 - frontend now CrashLoopBackOff](03-mini-project/screenshots/mini-bug-2-frontend-now-crashloopbackoff_24bcs10326.png)

![Bug 3 - frontend Pods are Running, but the site does not answer](03-mini-project/screenshots/mini-bug-3-frontend-pods-are-running-but-the-site-doe_24bcs10326.png)

![Bug 4 - the home page works, /api/products returns an error](03-mini-project/screenshots/mini-bug-4-the-home-page-works-api-products-returns-a_24bcs10326.png)

![Bug 5 - Pods Ready, endpoints present, still failing](03-mini-project/screenshots/mini-bug-5-pods-ready-endpoints-present-still-failing_24bcs10326.png)

![Final state and drift check against fixed/](03-mini-project/screenshots/mini-final-state-and-drift-check-against-fixed_24bcs10326.png)
