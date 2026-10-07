# Session 15 — Helm

| Task | Folder | Contents |
| --- | --- | --- |
| 1. Helm commands | [01-helm-commands/](01-helm-commands/) | `create`, `lint`, `template`, `install`, `list`, `status`, `get`, `upgrade`, `history`, `rollback`, `uninstall`, `repo`, `search`, `show` — each executed and explained |
| 2. Helm rollback | [02-rollback/](02-rollback/) | Install → upgrade → verify → **broken** upgrade → verify → rollback → verify |
| 3. Mini project | [03-mini-project/](03-mini-project/) | The `yatri-app` chart: templates, `values.yaml`, dev/prod overlays, tests, packaging |

Deliverables map:

| Deliverable | Where |
| --- | --- |
| Helm chart | [03-mini-project/yatri-app/](03-mini-project/yatri-app/) |
| values.yaml | [yatri-app/values.yaml](03-mini-project/yatri-app/values.yaml), [values-dev.yaml](03-mini-project/values-dev.yaml), [values-prod.yaml](03-mini-project/values-prod.yaml) |
| Templates | [yatri-app/templates/](03-mini-project/yatri-app/templates/) |
| Installation / upgrade / rollback | [01-helm-commands/EVIDENCE.md](01-helm-commands/EVIDENCE.md), [02-rollback/EVIDENCE.md](02-rollback/EVIDENCE.md) |
| Mini project | [03-mini-project/](03-mini-project/) |

Executed with Helm v3.22.0 on minikube v1.39.0 / Kubernetes v1.37.0.

## Results at a glance

```text
helm history yatri-app (rollback workflow)
REVISION  STATUS      DESCRIPTION
1         superseded  Install complete                                       Release v1, nginx 1.25
2         superseded  Upgrade complete                                       Release v2, nginx 1.26
3         failed      Upgrade "yatri-app" failed: context deadline exceeded  image tag 9.99-does-not-exist
4         deployed    Rollback to 2                                          back to v2 - users never saw v3
```
