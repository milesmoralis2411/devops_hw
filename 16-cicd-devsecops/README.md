# Session 17 — Complete CI/CD & DevSecOps

A CI/CD pipeline with security built into every stage — "shift left" — and a
**security gate** that blocks the release when policy is violated.

```text
Code → Build → Unit Test → SAST → SCA → Secret Scan → Docker Build → Container Image Scan
     → Security Gate → Push Image → Deploy to Kubernetes
```

| Deliverable | Where |
| --- | --- |
| Application | [`../15-cicd-github-actions/app/`](../15-cicd-github-actions/app/) — the same API as Session 16, so the focus here is the security pipeline around it |
| Dockerfile | [`../15-cicd-github-actions/app/Dockerfile`](../15-cicd-github-actions/app/Dockerfile) — multi-stage, tests inside the build, non-root runtime |
| GitHub Actions workflow | [`../.github/workflows/devsecops.yml`](../.github/workflows/devsecops.yml) |
| Security tool configuration | [security/](security/) — `gitleaks.toml`, `trivy.yaml`, `.trivyignore` |
| Kubernetes manifests | [kubernetes/](kubernetes/) — hardened Deployment + Service, NetworkPolicy |
| Pipeline output | [EVIDENCE.md](EVIDENCE.md) — every stage run locally with the same tools |

## The pipeline

```text
┌──────────┐   ┌──────────────────────────────────────────┐   ┌──────────────────┐   ┌──────────────┐   ┌──────┐   ┌────────┐
│ 1 build  │──►│ 2 SAST          3 SCA           4 secrets │──►│ 5 docker build   │──►│ 6 security   │──►│7 push│──►│8 deploy│
│ npm test │   │ CodeQL+Semgrep  npm audit+Trivy  Gitleaks  │   │   + Trivy image  │   │   gate       │   │ GHCR │   │  k8s   │
└──────────┘   │                 + SBOM          TruffleHog│   │   scan           │   │ 0 CRITICAL   │   └──────┘   └────────┘
               └──────────── run in parallel ──────────────┘   └──────────────────┘   └──────────────┘
                      results uploaded as SARIF to GitHub → Security → Code scanning
```

| Stage | Job | Tool(s) | What it catches | Fails the build when |
| --- | --- | --- | --- | --- |
| Build & test | `build` | npm, node:test | Broken code | Any test fails |
| **SAST** | `sast` | CodeQL (`security-extended`), Semgrep (`p/javascript`, `p/security-audit`) | Injection, `eval`, unsafe regex, hard-coded crypto, path traversal — in **our** code | Findings are reported to the Security tab |
| **SCA** | `sca` | `npm audit`, Trivy `fs`, Syft SBOM | Known CVEs in **dependencies**; IaC/Dockerfile misconfigurations | `npm audit --audit-level=high` |
| **Secret scanning** | `secret-scan` | Gitleaks (full history), TruffleHog (verified only) | API keys, tokens, private keys committed to Git | A leak is found |
| **Image scan** | `image-scan` | Trivy `image` | CVEs in the **OS packages and runtime** inside the image | Feeds the gate |
| **Security gate** | `security-gate` | policy script | — | Any fixable CRITICAL vulnerability |
| Push | `push` | docker | — | Runs only on `main`, only after the gate |
| Deploy | `deploy` | kubectl | — | `environment: production` — can require approval |

Design points:

- **The image that is pushed is the image that was scanned.** The
  `image-scan` job saves the exact image as an artifact; `push` loads that
  file rather than rebuilding, so nothing can change between scan and
  release.
- **The gate is a separate job,** so a red gate is unmistakable in the run
  graph, and `push` depends on it.
- **SARIF uploads** put every finding from every tool into one place —
  GitHub's Security tab — deduplicated and tracked across runs.
- **Least-privilege token:** `permissions` grants only `contents: read`,
  `packages: write` and `security-events: write`.
- **Policy as code:** [`security/trivy.yaml`](security/trivy.yaml) sets the
  severities and `ignore-unfixed`; [`.trivyignore`](security/.trivyignore) is
  the *reviewed* exception list, empty on purpose;
  [`gitleaks.toml`](security/gitleaks.toml) allow-lists the documented
  placeholders in this homework repo so real leaks stand out.

## SAST vs SCA vs secret scanning vs image scanning

| | SAST | SCA | Secret scanning | Image scanning |
| --- | --- | --- | --- | --- |
| Looks at | Your source code | Your dependency list | Every file and commit | The built image's OS packages and runtime |
| Finds | Code-level vulnerabilities | Known CVEs in libraries | Credentials | Known CVEs in the base image |
| Example | `exec('ls ' + userInput)` | an old `lodash` with a prototype-pollution CVE | `AKIA...` in `config.ini` | an outdated `openssl` in `node:14-alpine` |
| Fix by | Changing the code | Upgrading the dependency | **Rotating** the secret, then removing it | Rebuilding on a patched base image |

## Kubernetes hardening

[`kubernetes/deployment.yaml`](kubernetes/deployment.yaml) applies the runtime
half of DevSecOps:

| Setting | Closes |
| --- | --- |
| `runAsNonRoot: true`, `runAsUser: 1000` | Root inside the container |
| `allowPrivilegeEscalation: false` | setuid-based escalation |
| `readOnlyRootFilesystem: true` (+ an `emptyDir` for `/tmp`) | Dropping tools or tampering with the app on disk |
| `capabilities.drop: ["ALL"]` | Every Linux capability |
| `seccompProfile: RuntimeDefault` | Dangerous syscalls |
| `automountServiceAccountToken: false` | A free Kubernetes API token for an attacker |
| CPU/memory limits | Resource-exhaustion blast radius |
| [NetworkPolicy](kubernetes/networkpolicy.yaml) | Default-deny; only the frontend may connect; egress only to DNS |

## Pipeline output — every stage executed

Each stage was run locally with the same tools and settings as the workflow.
Full output is in [EVIDENCE.md](EVIDENCE.md).

| # | Stage | Result |
| --- | --- | --- |
| 1 | Build + unit tests | 7/7 pass |
| 2 | **SAST** (Semgrep `p/javascript` + `p/security-audit`) | Our `src/`: **0 findings**. Control test — a snippet with `exec('ls ' + name)` → `detect-child-process`, marked **Blocking** |
| 3 | **SCA** (`npm audit`, Trivy `fs`) | `found 0 vulnerabilities`; Trivy `fs` exit code 0 (no HIGH/CRITICAL vulnerabilities or misconfigurations) |
| 4 | **Secret scanning** (Gitleaks, 9 commits) | **1 real leak in this repository** (below). Control test — a throwaway repo with a fake AWS key → `aws-access-token` found |
| 5 | **Image scan** (Trivy) | alpine OS packages: 0. Node.js: **10 HIGH** — all inside npm's bundled dependencies |
| 5b | Remediation, rescan | npm/npx/yarn/corepack removed from the runtime stage → **0 HIGH, 0 CRITICAL** |
| 6 | **Security gate** (block on fixable CRITICAL) | `CRITICAL found: 0` → **PASSED**. Control test — `node:14-alpine` → 2 CRITICAL, Trivy exit code 1 → **FAILED** as designed |
| 7 | Deploy hardened manifests | 2/2 Ready; runs as uid 1000; writing to `/app` → `Read-only file system`; `/tmp` writable; NetworkPolicies applied |

### Finding 1 — a secret committed in this repository

```text
Finding:     POSTGRES_PASSWORD: REDACTED
RuleID:      generic-api-key
File:        11-kubernetes-ingress-configmaps-secrets/full-demo/secret.yaml
Line:        14
Commit:      47f0f69a5754627d645a2a15e20cef6a33331028
leaks found: 1
```

The Session 12 demo Secret holds a lab-only password, but the scanner is right:
it is a credential in Git history. For a real credential the response would be:
**rotate it first**, then replace the file with a reference — Sealed Secrets,
External Secrets, or `kubectl create secret` out-of-band — and rewrite history
only if the repository is public. Deleting the file in a new commit does not
remove it from history.

Because this one is a throwaway lab value, it was **baselined, not hidden**:
its exact fingerprint is listed in the repository's
[`.gitleaksignore`](../.gitleaksignore) with a comment pointing back here.
That suppresses only this one finding at this one commit and line. Any new
secret, including a change to the same file, still fails the scan:

```text
$ gitleaks detect --source . --redact      # full history, with .gitleaksignore
INF no leaks found                          exit=0
```

Once sessions 10–21 were committed, the scan found two more matches. Both
are deliberate lab values, so they were baselined the same way:

| Match | Why it is not a leak |
| --- | --- |
| `kubernetes-secret-yaml` in the Session 13 mini-project Secret | The value is literally `demo-token-not-a-real-secret` |
| `curl-auth-header` in the Session 21 evidence | A request sent with `x-api-key: wrong-key` on purpose, to show the HTTP 401 |

**CI note.** The pipeline pins `aquasecurity/trivy-action` to a commit SHA
(v0.36.0). The tag it first used, `0.28.0`, stopped resolving after upstream
re-published its tags with a `v` prefix. A pinned commit cannot be moved, so
the scanner that runs in CI cannot change under the pipeline.

### Finding 2 — vulnerabilities that came with the base image

```text
BEFORE  Node.js (node-pkg)   Total: 10 (HIGH: 10, CRITICAL: 0)
        brace-expansion ×5, ip-address (SSRF), pacote, picomatch (ReDoS), sigstore
AFTER   yatri-secure:scan (alpine 3.24.2)   Total: 0 (HIGH: 0, CRITICAL: 0)
```

None of these packages belong to the application — it has no dependencies.
They ship **inside npm**, which the `node:22-alpine` base image includes. The
running service only needs `node`, so the runtime stage now deletes npm, npx,
yarn and corepack, and the finding disappears.

Two notes from this fix:

- The gate in this session blocks on CRITICAL only, so these 10 HIGH would
  have **passed**. The [final project](../20-final-devops-project/)'s gate also
  caps HIGH (at most 5) and would have blocked them. Gate policy matters as
  much as the scanner.
- The image size stayed at **238 MB**. Deleting files in a later layer removes
  them from the running filesystem (and from Trivy's view) but not from the
  earlier layer's bytes. Actually shrinking the image needs a distroless or
  scratch-based final stage.

### Control tests

Each scanner was also pointed at something known-bad, to prove that a clean
result means "clean", not "not working":

| Scanner | Planted problem | Detected |
| --- | --- | --- |
| Semgrep | `exec('ls ' + userInput)` | `javascript.lang.security.detect-child-process` — Blocking |
| Gitleaks | `aws_access_key_id = AKIA…` committed | `aws-access-token` |
| Trivy + gate | `node:14-alpine` | CVE-2025-7783 (form-data), CVE-2026-59873 (tar), CRITICAL → exit 1 |

## Running the workflow on GitHub

The workflow triggers on changes to the app, this folder or the workflow
itself. SARIF results appear under **Security → Code scanning**. CodeQL needs
the repository to be public, or GitHub Advanced Security on a private
repository.
