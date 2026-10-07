# Final DevOps Project — Yatri Trips Platform

An end-to-end DevOps platform for a small REST API, built from everything in
the course: application → Git → CI → build & test → security scanning → Docker
image → container registry → Kubernetes → Helm → monitoring → GitOps — with
Terraform for the infrastructure, and a deliberately broken release to
troubleshoot at the end.

Everything in this README was **executed** on 2026-10-07 on minikube
(Kubernetes v1.37.0), Docker Desktop and Terraform v1.16.5. Verbatim output
is in [EVIDENCE.md](EVIDENCE.md) (deploy) and
[troubleshooting/EVIDENCE.md](troubleshooting/EVIDENCE.md) (incident).

## Contents

1. [Project overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Technologies](#3-technologies)
4. [Application](#4-application)
5. [Docker](#5-docker)
6. [Kubernetes](#6-kubernetes)
7. [Helm](#7-helm)
8. [Terraform infrastructure](#8-terraform-infrastructure)
9. [CI/CD pipeline](#9-cicd-pipeline)
10. [DevSecOps](#10-devsecops)
11. [Monitoring](#11-monitoring)
12. [GitOps](#12-gitops)
13. [Troubleshooting challenge](#13-troubleshooting-challenge)
14. [Screenshots](#14-screenshots)
15. [Lessons learned](#15-lessons-learned)

```text
20-final-devops-project/
├── application/           Node.js API (no runtime dependencies) + 12 unit tests
├── docker/                Dockerfile (test stage + non-root runtime), compose file
├── kubernetes/            plain manifests rendered from the chart (kustomize)
├── helm/yatri-trips/      the chart: Deployment, Service, Ingress, HPA, PDB, PVC, ConfigMap, Secret
├── terraform/
│   ├── aws/               VPC, EKS, ECR, S3, GitHub OIDC role
│   └── cluster-bootstrap/ namespaces + PSA, quota, limits, Secrets, Argo CD (Helm)
├── .github/workflows/     pipeline.yml - CI/CD + DevSecOps + GitOps deploy
├── security/              Semgrep rules, Gitleaks config, Trivy policy, security gate
├── monitoring/            Prometheus, alert rules, Alertmanager, Grafana, kube-state-metrics
├── gitops/                Argo CD app-of-apps + in-cluster Git server for the lab
├── scripts/pipeline.sh    the same pipeline, runnable locally
└── troubleshooting/       fault injector + incident write-up
```

## 1. Project overview

**Yatri Trips** is a small API for planning trips: list trips, create a trip
(with an API key), fetch one, delete one. It is deliberately simple, so that
the platform around it is the focus:

- the code is **tested** on every change and again inside the image build;
- every change is **scanned** (SAST, SCA, secrets, image CVEs) and blocked by a
  **security gate** if it fails policy;
- the image is **published** to a registry, and deployment happens by
  **committing the new tag to Git** — Argo CD does the rest;
- the cluster foundations (namespaces, guardrails, Secrets, Argo CD) are
  provisioned by **Terraform**, and so is the AWS infrastructure for
  production;
- the running system is **monitored** with metrics, logs and alerts —
  including an alert on the monitoring itself.

## 2. Architecture

```mermaid
flowchart LR
  dev([Developer]) -->|git push| gh[(GitHub)]
  gh --> ci

  subgraph ci[CI - GitHub Actions / scripts/pipeline.sh]
    t[Unit tests] --> sast[SAST<br/>Semgrep] & sca[SCA<br/>npm audit + Trivy fs] & sec[Secrets<br/>Gitleaks]
    sast & sca & sec --> b[Docker build<br/>tests run again]
    b --> scan[Trivy image scan] --> gate{Security gate}
  end

  gate -->|pass| reg[(Container registry<br/>ECR / lab registry)]
  gate -->|pass: commit image tag| cfg[(GitOps repo<br/>helm values)]

  subgraph k8s[Kubernetes cluster]
    argo[Argo CD] -->|sync| app[yatri-trips<br/>Deployment + HPA + PVC]
    argo -->|sync| mon[Prometheus · Alertmanager<br/>Grafana · kube-state-metrics]
    ing[Ingress] --> app
    mon -.scrapes.-> app
  end

  cfg -->|watched by| argo
  reg -->|image pull| app
  tf[Terraform] -->|cluster-bootstrap| k8s
  tf -->|aws/| aws[(VPC · EKS · ECR · S3)]
  user([User]) --> ing
```

Plain-text view of the delivery flow:

```text
Application ─► Git ─► CI: test ─► SAST/SCA/secrets ─► build ─► image scan ─► security gate
                                                                                │
                      ┌──────────────── push image ◄────────────────────────────┤
                      ▼                                                         ▼
              Container registry                              commit image.tag to GitOps repo
                      │                                                         │
                      │ pull                                         Argo CD polls / syncs
                      ▼                                                         ▼
          Kubernetes: Deployment · Service · Ingress · HPA · PVC · ConfigMap · Secret (Helm)
                      │
                      └──► Prometheus ─► Alertmanager ─► receiver      Grafana dashboards
```

## 3. Technologies

| Area | Tools |
| --- | --- |
| Application | Node.js 22, `node:test` (no dependencies) |
| Containers | Docker, multi-stage builds, BuildKit |
| Orchestration | Kubernetes (minikube for the lab, EKS for production) |
| Packaging | Helm 3 |
| Infrastructure as Code | Terraform — `hashicorp/aws`, `kubernetes`, `helm`, `random` |
| CI/CD | GitHub Actions; `scripts/pipeline.sh` for local runs |
| Security | Semgrep (SAST), npm audit + Trivy (SCA, misconfiguration), Gitleaks (secrets), Trivy (image), custom security gate, Pod Security Standards |
| Registry | Amazon ECR (production), `registry:2` (lab) |
| GitOps | Argo CD (app-of-apps), Gitea (lab Git server) |
| Monitoring | Prometheus, Alertmanager, Grafana, kube-state-metrics, cAdvisor, metrics-server |

## 4. Application

[`application/`](application/) — a dependency-free Node.js 22 HTTP API.

| Endpoint | Auth | Purpose |
| --- | --- | --- |
| `GET /` | — | Service name, version, environment |
| `GET /healthz` | — | Liveness: the process responds |
| `GET /readyz` | — | Readiness: the data volume is writable **and** an API key is configured |
| `GET /metrics` | — | Prometheus metrics: request counts and latency histograms by route, trips stored, auth failures, memory, CPU |
| `GET /api/trips` | — | List trips |
| `POST /api/trips` | `x-api-key` | Create `{destination, days}` (validated: 1–60 days, ≤100 chars) |
| `GET /api/trips/:id` | — | One trip |
| `DELETE /api/trips/:id` | `x-api-key` | Delete |

Engineering choices that matter for operations:

- **Config from the environment only** (`src/config.js`) — the same image runs
  everywhere; values come from the ConfigMap, and `API_KEY` from a Secret.
- **Persistence on a PVC.** Several HPA replicas share one data file, so every
  write takes an exclusive **lock file** (`O_EXCL`), re-reads, and writes
  atomically (temp file + `rename`). A test runs four separate processes
  writing concurrently and asserts that none of the 100 trips is lost. With
  locking disabled, the same test fails.
- **Constant-time API-key comparison** (`crypto.timingSafeEqual`).
- **Structured JSON logs**, one object per line, and never the key itself.
- **Graceful shutdown** on `SIGTERM`, so rolling updates do not drop requests.
- **Low-cardinality metrics:** routes are templated (`/api/trips/:id`), never
  raw IDs.

```bash
cd application && npm test        # 12 tests, node:test, no dependencies
```

## 5. Docker

[`docker/Dockerfile`](docker/Dockerfile) — two stages:

1. **`test`** — copies the source and tests, runs `npm run lint && npm test`.
2. **`runtime`** — `node:22-alpine`, `USER node` (uid 1000), `/data` volume,
   `HEALTHCHECK`, and OCI labels. It copies a marker file from the `test`
   stage, which **forces BuildKit to run the tests** — BuildKit otherwise
   skips stages the target does not depend on.

```bash
docker build -f docker/Dockerfile --build-arg APP_VERSION=1.0.0 -t yatri-trips:1.0.0 application/
docker compose -f docker/docker-compose.yml up --build      # API + Prometheus locally
```

> **Screenshots:** live output from the running platform, captured on 2026-10-08.

![Docker - build and run the stack locally with docker compose](screenshots/live-docker-build-and-run-the-stack-locally-with-dock_24bcs10326.png)

## 6. Kubernetes

Everything the assignment lists, all generated by the Helm chart (§7). Plain
manifests rendered from it are in [`kubernetes/`](kubernetes/) for anyone using
`kubectl apply -k`.

| Object | Configuration |
| --- | --- |
| **Deployment** | Rolling update `maxSurge 1 / maxUnavailable 0`; `revisionHistoryLimit 5`; checksum annotation rolls Pods on config change |
| **Service** | ClusterIP, named port `http` |
| **ConfigMap** | `APP_ENV`, `LOG_LEVEL`, `MAX_TRIPS` via `envFrom` |
| **Secret** | `API_KEY` — created by **Terraform**, referenced by name, never in Git |
| **Ingress** | `ingressClassName: nginx`, host `yatri-prod.local` |
| **HPA** | 2–8 replicas at 70% CPU; immediate scale-up, 120s scale-down window |
| **Probes** | startup `/healthz` (30×2s), readiness `/readyz`, liveness `/healthz` |
| **Storage** | PVC `yatri-trips-data` (`standard` StorageClass) mounted at `/data`, annotated `helm.sh/resource-policy: keep` so uninstalling never deletes data |
| **PodDisruptionBudget** | `minAvailable: 1` — node drains cannot take the API to zero |
| **Security** | Namespace enforces the **restricted** Pod Security Standard; Pods run as uid 1000, read-only root FS, all capabilities dropped, `RuntimeDefault` seccomp, no service-account token |
| **Guardrails** | `ResourceQuota` (CPU/memory/PVC/Pod caps) and `LimitRange` defaults on the namespace (Terraform) |

![Kubernetes - the running release in namespace yatri](screenshots/live-kubernetes-the-running-release-in-namespace-yatr_24bcs10326.png)

![Kubernetes - probes, resources and security context](screenshots/live-kubernetes-probes-resources-and-security-context_24bcs10326.png)

![Kubernetes - through the Ingress](screenshots/live-kubernetes-through-the-ingress_24bcs10326.png)

## 7. Helm

[`helm/yatri-trips/`](helm/yatri-trips/) renders 8 objects (Deployment, Service,
Ingress, HPA, PDB, PVC, ConfigMap, optional Secret) plus a `helm test` hook.
`values.yaml` holds defaults; `values-prod.yaml` holds production overrides,
**including `image.tag` — the line CI updates to deploy**.

```bash
helm lint helm/yatri-trips -f helm/yatri-trips/values-prod.yaml
helm template yatri-trips helm/yatri-trips -n yatri -f helm/yatri-trips/values-prod.yaml
```

Argo CD installs the chart (§12), so there is no `helm install` in the
deployment path. The chart guards itself: with `secret.create=true` and no key
it fails with `secret.create=true requires secret.apiKey (pass it with --set,
never commit it)`.

![Helm - the chart Argo CD deploys](screenshots/live-helm-the-chart-argo-cd-deploys_24bcs10326.png)

## 8. Terraform infrastructure

Two root modules, with different blast radii:

| Module | Provider(s) | Creates | Run here |
| --- | --- | --- | --- |
| [`terraform/aws/`](terraform/aws/) | `aws`, `random` | VPC across 2 AZs (public + private subnets, IGW, NAT, routes; no auto-assigned public IPs), **EKS** cluster (API endpoint **private by default**, KMS-encrypted Secrets, audit logs) + managed node group in private subnets, **ECR** repository (immutable tags, scan on push, lifecycle), **S3** backup bucket (versioned, customer-managed KMS key, public access blocked), **GitHub OIDC** provider + least-privilege CI role | `init` / `fmt` / `validate`, then against **LocalStack**: `plan` = 34 resources; **29 applied**, verified through the AWS APIs, destroyed. EKS and ECR return `501` (LocalStack Pro features). No AWS account was available |
| [`terraform/cluster-bootstrap/`](terraform/cluster-bootstrap/) | `kubernetes`, `helm`, `random` | Namespaces `yatri` (PSA restricted), `monitoring`, `argocd`; ResourceQuota + LimitRange; generated `API_KEY` and Grafana admin Secrets; **Argo CD** via `helm_release` | **Applied for real** against minikube |

The OIDC role means the CI pipeline can push to ECR with **no AWS keys stored in
GitHub** — the workflow's `id-token: write` permission is exchanged for
15-minute credentials limited to one repository.

**Running `terraform/aws` without an AWS account** (LocalStack 3.8, free
edition, which has no EKS or ECR; output in [EVIDENCE.md §11](EVIDENCE.md)):

```bash
docker run -d --name localstack -p 4566:4566 localstack/localstack:3.8
cd terraform/aws && cp localstack_override.tf.example override.tf
terraform init && terraform plan                     # Plan: 34 to add
terraform apply -target=random_id.suffix -target=aws_vpc.this   -target=aws_subnet.public -target=aws_subnet.private -target=aws_internet_gateway.this   -target=aws_eip.nat -target=aws_nat_gateway.this -target=aws_route_table.public   -target=aws_route_table.private -target=aws_route_table_association.public   -target=aws_route_table_association.private -target=aws_kms_key.eks -target=aws_kms_key.backups   -target=aws_s3_bucket.backups -target=aws_s3_bucket_versioning.backups   -target=aws_s3_bucket_server_side_encryption_configuration.backups   -target=aws_s3_bucket_public_access_block.backups -target=aws_iam_openid_connect_provider.github   -target=aws_iam_role.github_ci -target=aws_iam_role.cluster -target=aws_iam_role.node   -target=aws_iam_role_policy_attachment.cluster -target=aws_iam_role_policy_attachment.node
terraform destroy && rm override.tf                  # back to real AWS
```

![Terraform - cluster-bootstrap state matches the cluster](screenshots/live-terraform-cluster-bootstrap-state-matches-the-cl_24bcs10326.png)

![11. terraform/aws against LocalStack - plan everything, apply what it emulates](screenshots/tf-aws-11-terraform-aws-against-localstack-plan-everyth_24bcs10326.png)

![Plan - the whole configuration](screenshots/tf-aws-plan-the-whole-configuration_24bcs10326.png)

![Apply - everything except EKS and ECR](screenshots/tf-aws-apply-everything-except-eks-and-ecr_24bcs10326.png)

![Verify through the AWS APIs (boto3 -> LocalStack)](screenshots/tf-aws-verify-through-the-aws-apis-boto3-localstack_24bcs10326.png)

![Destroy](screenshots/tf-aws-destroy_24bcs10326.png)

## 9. CI/CD pipeline

[`.github/workflows/pipeline.yml`](.github/workflows/pipeline.yml). GitHub only
runs workflows from a repository's root, so this monorepo also carries an
identical copy at [`../.github/workflows/final-project.yml`](../.github/workflows/final-project.yml)
with paths prefixed.

```text
            ┌──────► sast ────────┐
 test ──────┼──────► sca  ────────┼──► build ──► (image scan + security gate) ──► push ──► gitops-deploy
            └──────► secret-scan ─┘       artifact: the scanned image        ECR via OIDC   commit image.tag
```

| Job | Does | Key detail |
| --- | --- | --- |
| `test` | lint + 12 unit tests | JUnit XML uploaded as an artifact |
| `sast` | Semgrep: `p/javascript`, `p/nodejs`, `p/security-audit` + project rules | `--error --severity ERROR` fails the job; SARIF to the Security tab |
| `sca` | `npm audit --audit-level=high`; Trivy `fs` over app + Dockerfile + Helm + Terraform | Dependency CVEs **and** IaC misconfigurations |
| `secret-scan` | Gitleaks over full history | Project config with a custom API-key rule; the one reviewed lab finding is baselined in the root [`.gitleaksignore`](../.gitleaksignore) |
| `build` | Buildx build (tests run again inside), Trivy image scan, **security gate**, save image | Tag `1.0.<run>-<sha7>` |
| `push` | Pushes **the scanned artifact** to ECR | OIDC role from `terraform/aws`; `environment: production` approval |
| `gitops-deploy` | Rewrites `image.tag` in `values-prod.yaml`, commits, pushes | No `kubectl` — Argo CD deploys |

`push` and `gitops-deploy` run only when the repository variable
`AWS_CI_ROLE_ARN` is set to the role ARN output by `terraform/aws`. Without an
AWS account the jobs are **skipped**, not failed, so every run still proves
test → scan → gate. The lab equivalent of these two stages is
[`scripts/pipeline.sh`](scripts/pipeline.sh), which pushes to the local
registry and commits the tag that Argo CD deploys.

The deploy commit edits a path excluded from the trigger
(`!helm/yatri-trips/values-prod.yaml`), so it cannot loop. `concurrency`
serialises deploys without cancelling a half-finished one.

**Run locally:** [`scripts/pipeline.sh <tag> <gitops-clone>`](scripts/pipeline.sh)
runs the same eight stages with the same tools (scanners as containers) and
ends by committing the tag to the GitOps repository. That is how the lab runs
below were driven.

## 10. DevSecOps

| Control | Tool / mechanism | Where |
| --- | --- | --- |
| SAST | Semgrep public packs + [`security/semgrep.yml`](security/semgrep.yml) (no `eval`, no `child_process` in `src/`, timing-safe key comparison) | CI `sast` |
| SCA | `npm audit`, Trivy `fs` | CI `sca`, `pipeline.sh` stage 3 |
| IaC / config scanning | Trivy misconfiguration scanner over the **whole project** — Dockerfile, Helm, rendered manifests, monitoring, GitOps, Terraform | CI `sca`, stage 3 |
| Secret scanning | Gitleaks + [`security/gitleaks.toml`](security/gitleaks.toml) | CI `secret-scan`, stage 4 |
| Image scanning | Trivy `image`, fixable HIGH/CRITICAL only | CI `build`, stage 6 |
| **Security gate** | [`security/security-gate.sh`](security/security-gate.sh) — fails on more than 0 CRITICAL or more than 5 HIGH | CI `build`, stage 7 |
| Supply chain | Scanned image = pushed image; immutable ECR tags; ECR scan on push | CI `push`, Terraform |
| Secrets management | Secrets generated by Terraform, never in Git; the chart refuses to template one without an explicit value | `cluster-bootstrap`, chart |
| Runtime hardening | PSA `restricted` namespace, non-root, read-only FS, no capabilities, seccomp, no SA token | Terraform + chart |
| Cloud identity | GitHub OIDC → 15-minute role credentials, scoped to one ECR repository | `terraform/aws` |
| Detection | `YatriAuthFailureSpike` alert on rejected API keys | monitoring |

### What the scanners found in this project, and what was done

The first whole-project scan reported **12 HIGH/CRITICAL** misconfigurations
(the application, Dockerfile and chart were already clean):

| Finding | Where | Action |
| --- | --- | --- |
| AVD-AWS-0040/0041 (CRITICAL): EKS API public, open to `0.0.0.0/0` | `terraform/aws` | **Fixed** — endpoint private unless specific CIDRs are given; a validation rule rejects `0.0.0.0/0` |
| AVD-AWS-0132: S3 not using a customer-managed key | `terraform/aws` | **Fixed** — dedicated KMS key with rotation |
| Public subnets auto-assign public IPs | `terraform/aws` | **Fixed** — `map_public_ip_on_launch = false` |
| KSV014 ×6: writable root filesystem | Prometheus, Alertmanager, alert-log, Grafana, kube-state-metrics, Gitea | **Fixed** — `readOnlyRootFilesystem: true` + `emptyDir` where they write |
| KSV041 (CRITICAL): kube-state-metrics can read Secrets | `monitoring/` | **Fixed** — `secrets` removed from its ClusterRole and from `--resources` |
| KSV047: Prometheus uses `nodes/proxy` | `monitoring/` | **Accepted** — required to scrape cAdvisor; documented with owner and review date in [`.trivyignore`](security/.trivyignore) |
| KSV-0118 ×5: no pod-level `securityContext` (found later, see below) | Prometheus, Alertmanager, alert-log, Grafana, kube-state-metrics | **Fixed** — each Pod runs as its image's non-root user with `fsGroup` and `RuntimeDefault` seccomp; alert-log moved to port 8080 |

After the fixes the scan exits 0, and the pipeline now gates on the whole
project rather than on the application folder alone.

**The scanner got stricter after the push.** The first GitHub Actions run
failed: `aquasecurity/trivy-action@0.28.0` no longer resolves (the upstream
tags were re-published with a `v` prefix), and the current release runs Trivy
0.70.0 instead of the 0.57.1 used locally. Its newer check KSV-0118 flagged the
five monitoring Deployments. The workflows now pin the action to a commit SHA
(v0.36.0), so a re-tagged release cannot change what runs. The fix went out
the GitOps way — one commit to the platform repo, which Argo CD rolled out —
and was verified in the cluster: all targets up, and a test alert reached
alert-log on its new port ([EVIDENCE.md §10](EVIDENCE.md)).

The image scan also found **10 HIGH** CVEs that came with the base image —
inside npm, which the runtime never uses. The runtime stage now deletes npm,
npx, yarn and corepack (details in
[Session 17](../16-cicd-devsecops/README.md#finding-2--vulnerabilities-that-came-with-the-base-image)).

![DevSecOps - tests, SAST, SCA + IaC, secret scan  (1/2)](screenshots/live-devsecops-tests-sast-sca-iac-secret-scan-1_24bcs10326.png)

![DevSecOps - tests, SAST, SCA + IaC, secret scan  (2/2)](screenshots/live-devsecops-tests-sast-sca-iac-secret-scan-2_24bcs10326.png)

![DevSecOps - image scan and the security gate](screenshots/live-devsecops-image-scan-and-the-security-gate_24bcs10326.png)

**One more finding from the screenshots run.** Scanning the *working folder*
(not just Git) flags `terraform/cluster-bootstrap/terraform.tfstate`: Terraform
state stores the generated API key and Grafana password in plain text. The file
is git-ignored and was never committed (`git log -- '*.tfstate'` is empty), so
CI's scan of the Git history is clean. In production the state belongs in an
encrypted remote backend, such as the S3 backend that is commented out in
`terraform/aws/versions.tf`, not on a laptop.

## 11. Monitoring

[`monitoring/`](monitoring/) is a kustomization deployed **by Argo CD**:

| Component | Role |
| --- | --- |
| Prometheus | Scrapes Pods annotated `prometheus.io/scrape` (the chart adds it), cAdvisor (container CPU/memory), kubelet (PVC usage) and kube-state-metrics (object state) |
| [Alert rules](monitoring/config/yatri-rules.yml) | Application: target down, no ready replicas, error rate > 5%, p95 > 500 ms, auth-failure spike. Platform: crash looping, Pods not ready, image pull failing, HPA maxed out, memory near limit, PVC almost full. **Meta:** `MonitoringTargetDown` — alerts when Prometheus loses any target (added after the incident in §13) |
| Alertmanager | Groups and routes (security → security on-call, critical → paging); the lab receiver logs payloads |
| Grafana | Datasource and the *Yatri Trips — Service Overview* dashboard (12 panels), provisioned from ConfigMaps; admin password from a Terraform Secret |
| kube-state-metrics | Deployment, HPA, Pod and restart state as metrics |

The Prometheus config and rules come from kustomize's `configMapGenerator`.
Each change produces a new hashed ConfigMap name, so **a Git commit that
edits an alert rule rolls Prometheus automatically** — no manual reload.

## 12. GitOps

```text
gitops/
├── root-app.yaml          the ONE object applied by hand (app of apps)
├── apps/
│   ├── monitoring.yaml    Application → monitoring/      (sync-wave 0)
│   └── yatri-trips.yaml   Application → helm/yatri-trips (sync-wave 1), values.yaml + values-prod.yaml
├── github-root-app.yaml   the same root, pointed at the GitHub monorepo
└── git-server/gitea.yaml  in-cluster Git server used for the lab
```

- `automated: {prune: true, selfHeal: true}` — Git is enforced, not merely
  suggested.
- `ignoreDifferences` on `/spec/replicas` — the HPA owns the replica count,
  so Argo CD must not fight it.
- **Why a lab Git server?** Deploying means *committing*. The demo makes many
  practice commits (releases, a broken release, fixes), so they go to an
  in-cluster Gitea that Argo CD watches exactly as it would watch GitHub.
  [`github-root-app.yaml`](gitops/github-root-app.yaml) is the production
  equivalent.

### The end-to-end run

Everything above was executed in one pass on minikube. Full output is in
[EVIDENCE.md](EVIDENCE.md).

| Step | What happened |
| --- | --- |
| 0. Lab registry | `registry:2` on the host; minikube's containerd configured (`certs.d/hosts.toml`) to pull from `host.minikube.internal:5000` |
| 1. `terraform apply` (cluster-bootstrap) | `Plan: 10 to add` → `Apply complete! Resources: 10 added` — namespaces (`yatri` with PSA `restricted`), quota, limit range, two generated Secrets (`(sensitive value)` throughout), Argo CD |
| 2. Git | Gitea up; the platform repository pushed (`793f2a9`) |
| 3. Pipeline v1.0.0 | 12/12 tests · `npm audit` 0 · whole-project Trivy clean · Gitleaks clean · image `0 HIGH/CRITICAL` · **gate PASSED** · pushed to registry · deploy commit `94d2997` |
| 4. GitOps | One `kubectl apply` (the root app). Argo CD created `yatri-monitoring` and `yatri-trips` from Git → all **Synced/Healthy** |
| 5. Verify | Image pulled from the registry, Pods as uid 1000 · Ingress serves `{"service":"yatri-trips","version":"1.0.0"}` · writes without the key → **401**, with the Terraform-generated key → 201 |
| 6. Monitoring | All 6 targets up; Pods labelled `version=1.0.0`; `yatri_trips_stored 3`; `promtool`: rules valid; Grafana dashboard provisioned |
| 7. Release v1.0.1 | Pipeline → commit `467828a` → Synced/Healthy in **11s** → both Pods on `1.0.1`; the three trips survived the rollout (PVC) |
| SAST | Semgrep, 86 rules including 3 custom: **0 findings** |
| `terraform/aws` | `init` / `fmt` / `validate`: `Success! The configuration is valid.` |
| `terraform/aws` on LocalStack | `Plan: 34 to add` · `Apply complete! Resources: 29 added` (all but EKS + ECR) · checked via boto3: private subnets with no public IPs, NAT route, S3 versioned + `aws:kms` + public access blocked, both KMS keys rotating, CI role trusts only `repo:milesmoralis2411/devops_hw:ref:refs/heads/main` · `Destroy complete! Resources: 29 destroyed` |
| Pipeline in GitHub Actions | First run: `trivy-action@0.28.0` no longer resolves, Trivy 0.70.0's KSV-0118 → action pinned by SHA, monitoring Pods hardened via GitOps ([§10](EVIDENCE.md)) |

## 13. Troubleshooting challenge

A single "release 1.1.0" commit injected **five faults**: a memory request
over the namespace quota, an image tag that was never built, a renamed
Secret, an Ingress host typo, and a scrape-target typo. They were diagnosed
and fixed **one Git commit at a time**:

```text
eaa1b8d fix: kube-state-metrics scrape target                         <- 5. monitoring blind
5d76137 fix: ingress host typo yatri-prod.locl -> yatri-prod.local    <- 4. 404
1fe51f4 fix: use the Terraform-managed secret yatri-trips-secret       <- 3. CreateContainerConfigError
8fdd45e deploy: yatri-trips 1.1.0                                      <- 2. ImagePullBackOff: build it properly
1b6d7f8 fix: memory request back within the yatri ResourceQuota        <- 1. ReplicaSet FailedCreate
79fc385 release 1.1.0: new version, more memory, renamed secret, ...   <- the bad release
```

Throughout, the v1.0.1 Pods kept serving (the rolling update never removed
them), and the trips written before the incident were intact at the end.
The full investigation — commands, root causes, fixes, before/after, and the
post-incident actions — is in
[troubleshooting/README.md](troubleshooting/README.md).

> These are the terminal output captured *during* the incident run (verbatim in
> [troubleshooting/EVIDENCE.md](troubleshooting/EVIDENCE.md)), rendered as images; the incident was not re-staged.

![The bad release](troubleshooting/screenshots/incident-the-bad-release-1_24bcs10326.png)

![Symptom report](troubleshooting/screenshots/incident-symptom-report_24bcs10326.png)

![Issue 1 - the new version never starts: ResourceQuota  (1/2)](troubleshooting/screenshots/incident-issue-1-the-new-version-never-starts-resourcequo-1_24bcs10326.png)

![Issue 1 - the new version never starts: ResourceQuota  (2/2)](troubleshooting/screenshots/incident-issue-1-the-new-version-never-starts-resourcequo-2_24bcs10326.png)

![Issue 2 - ImagePullBackOff: the image was never published](troubleshooting/screenshots/incident-issue-2-imagepullbackoff-the-image-was-never-pub_24bcs10326.png)

![Issue 3 - CreateContainerConfigError: wrong Secret name](troubleshooting/screenshots/incident-issue-3-createcontainerconfigerror-wrong-secret-_24bcs10326.png)

![Issue 4 - still 404: the Ingress host](troubleshooting/screenshots/incident-issue-4-still-404-the-ingress-host_24bcs10326.png)

![Issue 5 - why did nobody get paged? Monitoring was half-blind](troubleshooting/screenshots/incident-issue-5-why-did-nobody-get-paged-monitoring-was-_24bcs10326.png)

![Final state](troubleshooting/screenshots/incident-final-state_24bcs10326.png)

![Post-incident action 1 - alert on the monitoring itself](troubleshooting/screenshots/incident-post-incident-action-1-alert-on-the-monitoring-i_24bcs10326.png)

![Post-incident action 2 - game day: break the scrape target on purpose, confirm it pages](troubleshooting/screenshots/incident-post-incident-action-2-game-day-break-the-scrape_24bcs10326.png)

![Post-incident action 3 - revert the game-day break](troubleshooting/screenshots/incident-post-incident-action-3-revert-the-game-day-break_24bcs10326.png)

## 14. Screenshots

Terminal screenshots sit next to the part they show: Docker (§5), Kubernetes
(§6), Helm (§7), Terraform (§8), DevSecOps (§10) and every step of the
troubleshooting challenge (§13). The verbatim text is in [EVIDENCE.md](EVIDENCE.md)
and [troubleshooting/EVIDENCE.md](troubleshooting/EVIDENCE.md). Below is the same
running platform in the browser, captured on 2026-10-07 after the incident and
the hardening rollout.

**Argo CD** — the App of Apps (`yatri-root`) and the two Applications it
manages, all Synced / Healthy. `yatri-gitops` is the Session 20 demo, synced
from GitHub.

![Argo CD applications](screenshots/argocd-applications_24bcs10326.png)

**`yatri-trips`** — Deployment, HPA, PDB, PVC, Ingress, and the ReplicaSet
history of the incident: one ReplicaSet per release and fix.

![Argo CD yatri-trips tree](screenshots/argocd-yatri-trips-tree_24bcs10326.png)

**`yatri-monitoring`** — synced to `4097b57`, the hardening commit.

![Argo CD yatri-monitoring resources](screenshots/argocd-yatri-monitoring-list_24bcs10326.png)

**Grafana** — the provisioned *Yatri Trips – Service Overview* dashboard, with
live traffic through the Ingress. *Error ratio* shows "No data" because there
were no 5xx responses to divide. *PVC usage* has no data because minikube's
hostPath provisioner does not report kubelet volume stats.

![Grafana dashboard](screenshots/grafana-yatri-dashboard_24bcs10326.png)

**Prometheus** — all 6 targets up, and the 12 alert rules. The traffic
generator also sent unauthenticated writes on purpose, and
**`YatriAuthFailureSpike` fired** (11.6 auth failures/min in Grafana above).

![Prometheus targets](screenshots/prometheus-targets_24bcs10326.png)

![Prometheus alert rules](screenshots/prometheus-alert-rules_24bcs10326.png)

**Alertmanager** — that alert routed to the `alert-log` receiver (team
`security`).

![Alertmanager](screenshots/alertmanager-alerts_24bcs10326.png)

**Gitea** — the platform repository's history: the incident, its fixes, the
post-incident alert, the game day, and the hardening commit.

![Gitea commit history](screenshots/gitea-platform-history_24bcs10326.png)

**GitHub Actions** — the pipeline on the monorepo ([run #2](https://github.com/milesmoralis2411/devops_hw/actions/runs/37663251908)):
test → SAST / SCA / secret scan → build + image scan + gate pass. *Push to
ECR* and *GitOps deploy* are skipped until `AWS_CI_ROLE_ARN` is set
([section 9](#9-cicd-pipeline)).

![GitHub Actions pipeline](screenshots/github-actions-pipeline_24bcs10326.png)

To open them yourself, with the lab running:

| View | Command | URL |
| --- | --- | --- |
| Argo CD (app tree, sync history) | `kubectl -n argocd port-forward svc/argocd-server 8080:80` | http://localhost:8080 — user `admin`, password from `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Grafana dashboard | `kubectl -n monitoring port-forward svc/grafana 3000:3000` | http://localhost:3000/d/yatri-trips — password from `terraform -chdir=terraform/cluster-bootstrap output -raw grafana_admin_password` |
| Prometheus alerts / targets | `kubectl -n monitoring port-forward svc/prometheus 9090:9090` | http://localhost:9090/alerts |
| The API | `kubectl -n yatri port-forward svc/yatri-trips 8081:80` | http://localhost:8081/api/trips |

## 15. Lessons learned

These came from actually running the platform, not from theory:

1. **Git is the deployment interface — so treat commits like deployments.**
   The incident was caused by one plausible-looking commit, and fixed by five
   small commits. `git log` became the incident timeline for free.
2. **Monitor the monitoring.** A one-character typo in a scrape target
   silenced every alert built on kube-state-metrics for the whole incident,
   and **nothing paged** — no rule watched Prometheus's own targets. The
   broken target was only found by reading the targets list by hand. The
   meta-alert `MonitoringTargetDown` was added afterwards, and a game-day test
   (breaking the target on purpose) proved that it fires and reaches
   Alertmanager.
3. **Failures stack.** ResourceQuota → missing image → wrong Secret were all in
   one Deployment, and each hid the next. Fixing one error and getting a new
   one is progress.
4. **Look one level up.** When no Pod exists, Pod events are empty. The quota
   rejection only appeared on the **ReplicaSet**.
5. **The rolling update strategy is a safety net.** With
   `maxUnavailable: 0`, every broken version in the incident (quota, image,
   Secret) failed to start *alongside* the healthy old Pods, so the API kept
   serving data throughout. The 404 users saw came from the Ingress typo, not
   from the broken rollouts.
6. **Never deploy a tag that does not exist yet.** The pipeline builds,
   scans, pushes and only *then* commits the tag. Bumping it by hand skipped
   all of that.
7. **Secrets belong to the platform, not the chart.** Terraform generated
   them; the chart only references them by name; Git never sees a value.
8. **Hardening needs testing.** Dropping all Linux capabilities crash-looped
   stock nginx in Session 15. Security settings are code and break like
   code.
9. **The environment shapes the evidence.** A slow link exposed the kubelet's
   serialised image pulls, `:latest` meaning `imagePullPolicy: Always`,
   Argo CD's 90-second git timeout and 3-minute revision cache, and
   minikube's node reporting 24 CPUs instead of 2. Every one of those is a
   real production behaviour, just easier to miss on a fast network.
10. **Concurrency bugs hide in "simple" persistence.** A JSON file on a PVC is
    fine for one Pod and wrong for an autoscaled Deployment. The four-process
    test only passes with locking.
