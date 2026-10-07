# Final Troubleshooting Challenge

> *"Release 1.1.0 just went out. `yatri-prod.local` returns 404 and nobody got
> paged."*

[`inject-faults.sh`](inject-faults.sh) creates **one** commit that looks like a
routine release:

```text
release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up
```

It hides **five independent faults**, spread across the application and the
monitoring that is supposed to catch problems:

| # | Change in the commit | Fault |
| --- | --- | --- |
| A | `image.tag: "1.1.0"` | The image was never built — the tag was bumped by hand |
| B | `secret.existingSecret: yatri-api-key` | The Secret was "renamed" in values only; the real one is `yatri-trips-secret` |
| C | `requests.memory: 5Gi` | Exceeds the namespace `ResourceQuota` (4Gi of requests in total) |
| D | `ingress.host: yatri-prod.locl` | Typo in the public hostname |
| E | scrape target `kube-state-metric…` | Typo; every alert built on kube-state-metrics goes blind |

A, B and C all hit the same Deployment, so they surface **one after another**:
C stops Pods being created at all, which hides A; fixing C reveals A; fixing A
reveals B. D and E are independent, and E is what made the outage silent.

Every fix is a **Git commit** to the GitOps repository; Argo CD applies it.
Nothing is `kubectl edit`-ed — which also means the fixes cannot be
silently reverted by the next sync.

The full run is in [EVIDENCE.md](EVIDENCE.md).

## Symptom

```text
$ curl -H 'Host: yatri-prod.local' http://<ingress>/   -> HTTP 404
yatri-trips:      sync=Synced health=Degraded
yatri-monitoring: sync=Synced health=Healthy
```

Argo CD had applied the commit faithfully — it was **Synced** — but the
application was **Degraded**. GitOps guarantees the cluster matches Git, not
that Git is correct.

> **Screenshots:** the terminal output captured *during* the incident run on 2026-10-07 (the verbatim text is in [EVIDENCE.md](EVIDENCE.md)), rendered as images. The incident was not re-staged for the screenshots: re-breaking the live platform would not reproduce it, because the 1.1.0 image now exists.

![The bad release](screenshots/incident-the-bad-release-1_24bcs10326.png)

![Symptom report](screenshots/incident-symptom-report_24bcs10326.png)

## Issue 1 — the new version never starts (ResourceQuota)

**Identify**

```text
deployment yatri-trips   2/2   UP-TO-DATE 0
yatri-trips-5ffccc9d67   DESIRED 1   CURRENT 0      <- new ReplicaSet, zero Pods
yatri-trips-c8c4f95df    DESIRED 2   CURRENT 2      <- v1.0.1 still serving
```

**Investigate.** No new Pod exists, so there are no Pod events to read. The
answer is one level up, on the ReplicaSet:

```text
$ kubectl -n yatri describe rs yatri-trips-5ffccc9d67
Warning  FailedCreate  replicaset-controller  Error creating: pods "yatri-trips-5ffccc9d67-q8w7l" is forbidden:
         exceeded quota: yatri-quota, requested: requests.memory=5Gi, used: requests.memory=192Mi,
         limited: requests.memory=4Gi
```

**Root cause:** the release raised the memory request to 5Gi; the namespace
`ResourceQuota` (from Terraform) caps requests at 4Gi in total.
**Fix:** commit `1b6d7f8` restores 96Mi / 256Mi. **Verify:** a new Pod is
created — and immediately shows the next problem.

![Issue 1 - the new version never starts: ResourceQuota  (1/2)](screenshots/incident-issue-1-the-new-version-never-starts-resourcequo-1_24bcs10326.png)

![Issue 1 - the new version never starts: ResourceQuota  (2/2)](screenshots/incident-issue-1-the-new-version-never-starts-resourcequo-2_24bcs10326.png)

## Issue 2 — ImagePullBackOff (the image was never published)

```text
Failed to pull image "host.minikube.internal:5000/yatri-trips:1.1.0": ... not found

$ curl -s http://localhost:5000/v2/yatri-trips/tags/list
{"name":"yatri-trips","tags":["1.0.0","1.0.1"]}           <- no 1.1.0
```

**Root cause:** the tag in `values-prod.yaml` was bumped **by hand**. The
pipeline that builds, scans and pushes the image never ran for 1.1.0.
**Fix:** run the real release pipeline for 1.1.0: tests → scans →
**gate PASSED** → push. Registry tags became `["1.1.0","1.0.0","1.0.1"]`
(deploy commit `8fdd45e`). The stuck Pod was deleted so the kubelet retried
immediately instead of waiting out its pull back-off.

![Issue 2 - ImagePullBackOff: the image was never published](screenshots/incident-issue-2-imagepullbackoff-the-image-was-never-pub_24bcs10326.png)

## Issue 3 — CreateContainerConfigError (wrong Secret name)

```text
Error: secret "yatri-api-key" not found

$ kubectl -n yatri get secrets
yatri-trips-secret   Opaque   1                  <- the only Secret, created by Terraform

$ git log -p -1 79fc385 -- helm/yatri-trips/values-prod.yaml
+secret:
+  create: false
+  existingSecret: yatri-api-key
```

**Root cause:** the release "renamed" the Secret in the Helm values only.
**Fix:** commit `1fe51f4` removes the override. **Verify:** the rollout
completes, and both new Pods run `yatri-trips:1.1.0` and are Ready.

![Issue 3 - CreateContainerConfigError: wrong Secret name](screenshots/incident-issue-3-createcontainerconfigerror-wrong-secret-_24bcs10326.png)

## Issue 4 — still 404 (Ingress host typo)

```text
$ kubectl -n yatri get ingress
NAME          CLASS   HOSTS             ADDRESS
yatri-trips   nginx   yatri-prod.locl   192.168.49.2      <- "locl"
```

**Root cause:** typo in the hostname, so the controller has no rule for
`yatri-prod.local`. **Fix:** commit `5d76137`. **Verify:**

```text
$ curl -H 'Host: yatri-prod.local' http://<ingress>/   -> HTTP 200
{"service":"yatri-trips","version":"1.1.0","env":"production"}
```

![Issue 4 - still 404: the Ingress host](screenshots/incident-issue-4-still-404-the-ingress-host_24bcs10326.png)

## Issue 5 — why did nobody get paged?

```text
Prometheus targets:
  kube-state-metrics   down  Get "http://kube-state-metric.monitoring.svc:8080/metrics": dial tcp: lookup kube-state-metric...
Active alerts:
  YatriTargetDown   critical   pending   Prometheus cannot scrape yatri-trips-6c8f6b6485-kn4f2
```

**Root cause:** the release also "tidied" the scrape config —
`kube-state-metric` (missing *s*). Every alert built on kube-state-metrics —
no ready replicas, image pull failing, Pods not ready, crash looping — had no
data for the whole incident, so **nothing paged**. The only alert that even
reached *pending* was `YatriTargetDown`, for the one unready Pod. The broken
target was found by reading the targets list by hand.

**Fix:** commit `eaa1b8d`. Because the config comes from kustomize's
`configMapGenerator`, the fix produced a new ConfigMap
(`prometheus-config-4fb2md2c7g`) and Prometheus rolled automatically. All 6
targets were back `up`, with no active alerts.

![Issue 5 - why did nobody get paged? Monitoring was half-blind](screenshots/incident-issue-5-why-did-nobody-get-paged-monitoring-was-_24bcs10326.png)

## Final state

```text
yatri-root:       sync=Synced health=Healthy
yatri-monitoring: sync=Synced health=Healthy
yatri-trips:      sync=Synced health=Healthy

deployment.apps/yatri-trips   2/2
{"service":"yatri-trips","version":"1.1.0","env":"production"}
"destination":"Jaipur"  "destination":"Leh"  "destination":"Hampi"     <- data from before the incident
```

**Blast radius.** With `maxUnavailable: 0`, every broken ReplicaSet (quota,
image, Secret) failed *alongside* the two healthy v1.0.1 Pods, which kept
serving and kept the data. Users lost the hostname to the Ingress typo
(fault D); the broken rollouts alone would not have taken the API down.

![Final state](screenshots/incident-final-state_24bcs10326.png)

## Post-incident actions

The review question was: *how do we make fault E impossible to miss?*

**1. Alert on the monitoring itself.** A new rule group:

```yaml
- alert: MonitoringTargetDown
  expr: up == 0
  for: 2m
  labels: { severity: critical, team: platform }
```

It was committed (`a980d81`); Prometheus rolled automatically, and
`promtool check rules` → `SUCCESS: 12 rules found`.

**2. Game day — prove it works.** The same typo was re-introduced on purpose
(`fe5a5af`):

```text
# 164s after Prometheus restarted with the broken config:
Prometheus:    MonitoringTargetDown   critical   firing   Prometheus cannot scrape job kube-state-metrics ...
Alertmanager:  MonitoringTargetDown   active     receivers=['alert-log']
Receiver:      "status":"firing","labels":{"alertname":"MonitoringTargetDown","job":"kube-state-metrics","severity":"critical","team":"platform"...
```

![Post-incident action 1 - alert on the monitoring itself](screenshots/incident-post-incident-action-1-alert-on-the-monitoring-i_24bcs10326.png)

![Post-incident action 2 - game day: break the scrape target on purpose, confirm it pages](screenshots/incident-post-incident-action-2-game-day-break-the-scrape_24bcs10326.png)

![Post-incident action 3 - revert the game-day break](screenshots/incident-post-incident-action-3-revert-the-game-day-break_24bcs10326.png)

**3. Revert** (`e9a7d85`) → all 6 targets `up`, no active alerts, every
Application Synced/Healthy.

## The incident as Git history

```text
e9a7d85 Revert "game day: break the kube-state-metrics scrape target"
fe5a5af game day: break the kube-state-metrics scrape target
a980d81 post-incident: alert when any scrape target is down (MonitoringTargetDown)
eaa1b8d fix: kube-state-metrics scrape target
5d76137 fix: ingress host typo yatri-prod.locl -> yatri-prod.local
1fe51f4 fix: use the Terraform-managed secret yatri-trips-secret
8fdd45e deploy: yatri-trips 1.1.0
1b6d7f8 fix: memory request back within the yatri ResourceQuota
79fc385 release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up
467828a deploy: yatri-trips 1.0.1
94d2997 deploy: yatri-trips 1.0.0
793f2a9 Yatri platform: app, chart, monitoring, gitops
```

## Takeaways

| Lesson | From |
| --- | --- |
| "Synced" is not "working" — GitOps faithfully deploys a bad commit | Symptom |
| When there is no Pod, read the ReplicaSet's events | Issue 1 |
| Never bump a tag by hand; only the pipeline publishes images | Issue 2 |
| Secrets are referenced by name; renaming one in values breaks the contract | Issue 3 |
| Test the user-facing path, not just Pod status | Issue 4 |
| Monitor the monitoring — and test alerts by breaking things on purpose | Issue 5 + game day |
| A conservative rolling update turns broken releases into non-events | Blast radius |
