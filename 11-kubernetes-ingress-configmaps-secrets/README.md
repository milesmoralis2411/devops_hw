# Kubernetes Ingress, ConfigMaps, and Secrets

This full demo runs a frontend and backend behind one Ingress rule.

```text
yatri.local/       → Frontend Service → NGINX Pods
yatri.local/api/   → Backend Service  → Python Pods
```

## ConfigMap

The ConfigMap stores non-sensitive application settings such as the
environment, log level, currency, and port. Both workloads receive these values
as environment variables, so configuration can change without rebuilding an
image.

> **Screenshots:** live output from a run on 2026-10-07. Secret values are masked.

![ConfigMap created, injected with envFrom, verified inside both containers](full-demo/demo-task-1-configmap-created-injected-verified-insid_24bcs10326.png)

## Secret

The Secret stores the database username, password, and database name. The
backend receives these as environment variables. Secret values are Base64
encoded, not encrypted, so they should never be printed in screenshots.

### Why Secrets should not be committed to Git

A Kubernetes Secret is **base64-encoded, not encrypted**. Anyone who can read
the YAML can decode it in one command:

```bash
echo 'cGFzc3dvcmQxMjM=' | base64 -d      # -> password123
```

Committing that YAML to Git causes problems that cannot be undone by deleting
the file later:

- **Git history is permanent.** A later commit that removes the file leaves the
  value in every clone, every fork and every CI cache. Removing it properly
  means rewriting history, and the credential must be rotated anyway.
- **Repositories leak.** They get made public, cloned to laptops, mirrored and
  shared with contractors. Bots scan public GitHub for credentials within
  minutes of a push.
- **Access is too broad.** Everyone with repository read access gets
  production credentials, which defeats Kubernetes RBAC on Secrets.

What to do instead:

| Approach | How it works |
| --- | --- |
| Create Secrets out-of-band | `kubectl create secret generic db --from-literal=password=...` — never written to a file |
| Sealed Secrets | Commit an *encrypted* `SealedSecret`; only the in-cluster controller can decrypt it |
| External Secrets Operator | Commit a reference; values are pulled from AWS Secrets Manager, Vault or GCP Secret Manager |
| SOPS | Encrypt the values inside the YAML with KMS or age keys; safe to commit |
| Secret scanning | Gitleaks or TruffleHog in pre-commit hooks and CI ([Session 17](../16-cicd-devsecops/)) to stop leaks before they land |

The `secret.yaml` in this demo holds throwaway lab values. A real project
would use one of the approaches above.

![Secret created, injected with secretKeyRef, verified without printing values](full-demo/demo-task-2-secret-created-injected-verified-values-n_24bcs10326.png)

## Ingress

The NGINX Ingress controller provides one entry point for both services.
Requests to `/` reach the frontend, while requests to `/api/` are routed to the
backend. The rewrite rule removes the `/api` prefix before the backend receives
the request.

![Ingress rules, both routes answering, unknown host 404](full-demo/demo-task-3-ingress-one-entry-point-two-routes_24bcs10326.png)

## Evidence

The terminal test confirms that the Ingress routes the root path to the
frontend and `/api/` to the backend. The backend response displays values from
the ConfigMap and non-sensitive Secret fields; the password is not shown.

![Frontend and backend responses through Ingress](full-demo/ingress-routes_24bcs10326.png)

The frontend is available at `yatri.local/` through the Ingress rule.

![Frontend route through Ingress](full-demo/ingress-frontend_24bcs10326.png)

The `/api/` route reaches the backend and confirms the injected configuration
and database username and name.

![Backend API route through Ingress](full-demo/ingress-backend_24bcs10326.png)

## Task 4 — Ingress vs Ingress Controller

[ingress-vs-ingress-controller/README.md](ingress-vs-ingress-controller/README.md)
explains what each one is, how they differ, why both are required, and gives
examples — including how to recognise an Ingress that no controller has
claimed.

## Task 5 — Troubleshooting

[troubleshooting/README.md](troubleshooting/README.md) covers four broken
scenarios: a missing ConfigMap, a wrong Secret key, an Ingress pointing at a
non-existent Service, and an Ingress with a class no controller implements.
Each was identified, investigated, root-caused, fixed and verified, with
before/after output in [troubleshooting/EVIDENCE.md](troubleshooting/EVIDENCE.md).

![Case 01 before / fix / after](troubleshooting/screenshots/ts-case-01-pod-references-a-missing-configmap_24bcs10326.png)

![Case 02 before / fix / after](troubleshooting/screenshots/ts-case-02-secret-exists-but-the-key-name-is-wrong_24bcs10326.png)

![Case 03 before / fix / after](troubleshooting/screenshots/ts-case-03-ingress-points-at-a-service-name-that-do_24bcs10326.png)

![Case 04 before / fix / after](troubleshooting/screenshots/ts-case-04-ingress-names-an-ingressclass-no-control_24bcs10326.png)

![Why a class-less Ingress still works on minikube](troubleshooting/screenshots/ts-note-why-an-ingress-with-no-class-still-works-on_24bcs10326.png)

## Key Takeaway

ConfigMaps separate ordinary configuration from images, Secrets keep sensitive
values out of application code, and Ingress gives multiple services one
host-based, path-based entry point.
