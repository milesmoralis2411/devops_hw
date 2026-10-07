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

## Screenshots

Live output from a second run of every task on 2026-10-08. Each image also
sits next to its explanation in the task's own README.

### Task 1 — Helm commands

![helm version](01-helm-commands/screenshots/cmd-helm-version_24bcs10326.png)

![helm create - scaffold a new chart](01-helm-commands/screenshots/cmd-helm-create-scaffold-a-new-chart_24bcs10326.png)

![helm template / lint - render locally without a cluster](01-helm-commands/screenshots/cmd-helm-template-lint-render-locally-without-a-clus_24bcs10326.png)

![helm install](01-helm-commands/screenshots/cmd-helm-install_24bcs10326.png)

![helm list](01-helm-commands/screenshots/cmd-helm-list_24bcs10326.png)

![helm status](01-helm-commands/screenshots/cmd-helm-status_24bcs10326.png)

![helm get](01-helm-commands/screenshots/cmd-helm-get_24bcs10326.png)

![The release is real Kubernetes objects](01-helm-commands/screenshots/cmd-the-release-is-real-kubernetes-objects_24bcs10326.png)

![helm upgrade](01-helm-commands/screenshots/cmd-helm-upgrade_24bcs10326.png)

![helm history](01-helm-commands/screenshots/cmd-helm-history_24bcs10326.png)

![helm rollback](01-helm-commands/screenshots/cmd-helm-rollback_24bcs10326.png)

![helm uninstall](01-helm-commands/screenshots/cmd-helm-uninstall_24bcs10326.png)

![helm repo](01-helm-commands/screenshots/cmd-helm-repo_24bcs10326.png)

![helm search  (1/2)](01-helm-commands/screenshots/cmd-helm-search-1_24bcs10326.png)

![helm search  (2/2)](01-helm-commands/screenshots/cmd-helm-search-2_24bcs10326.png)

### Task 2 — Rollback workflow (install → upgrade → verify → broken upgrade → verify → rollback → verify)

![1. Install - revision 1 (nginx 1.25, greeting v1)](02-rollback/screenshots/rb-1-install-revision-1-nginx-1-25-greeting-v1_24bcs10326.png)

![2. Upgrade - revision 2 (nginx 1.26, greeting v2)](02-rollback/screenshots/rb-2-upgrade-revision-2-nginx-1-26-greeting-v2_24bcs10326.png)

![3. Verify](02-rollback/screenshots/rb-3-verify_24bcs10326.png)

![4. Upgrade again - revision 3 ships a broken image tag](02-rollback/screenshots/rb-4-upgrade-again-revision-3-ships-a-broken-image-_24bcs10326.png)

![5. Verify - the upgrade failed](02-rollback/screenshots/rb-5-verify-the-upgrade-failed_24bcs10326.png)

![6. Rollback to revision 2](02-rollback/screenshots/rb-6-rollback-to-revision-2_24bcs10326.png)

![7. Verify](02-rollback/screenshots/rb-7-verify_24bcs10326.png)

### Task 3 — Mini project: one chart, dev and prod

![One chart, two environments](03-mini-project/screenshots/mini-one-chart-two-environments_24bcs10326.png)

![What each environment got](03-mini-project/screenshots/mini-what-each-environment-got_24bcs10326.png)

![Reach the prod release through the Ingress](03-mini-project/screenshots/mini-reach-the-prod-release-through-the-ingress_24bcs10326.png)

![Secrets and ConfigMap are injected](03-mini-project/screenshots/mini-secrets-and-configmap-are-injected_24bcs10326.png)

![Config change rolls the Pods automatically (checksum annotation)](03-mini-project/screenshots/mini-config-change-rolls-the-pods-automatically-check_24bcs10326.png)

![helm test](03-mini-project/screenshots/mini-helm-test_24bcs10326.png)

![Package the chart](03-mini-project/screenshots/mini-package-the-chart_24bcs10326.png)
