# Session 16 — CI/CD with GitHub Actions

A complete demo project: a small Node.js API with unit tests, a multi-stage
Dockerfile, a **CI** workflow that builds, tests and smoke-tests the image, and
a **CD** workflow that pushes it to a container registry and deploys it to
Kubernetes.

```text
15-cicd-github-actions/
├── app/
│   ├── src/app.js            # request handling (pure, testable)
│   ├── src/server.js         # HTTP listener + graceful shutdown
│   ├── test/app.test.js      # 7 unit tests (node:test, no dependencies)
│   ├── Dockerfile            # deps -> test -> runtime, non-root
│   └── package.json
├── kubernetes/
│   ├── deployment.yaml       # probes, resources, 2 replicas
│   └── service.yaml          # NodePort 30080
├── EVIDENCE.md               # local build/test/run output
└── README.md

.github/workflows/            # at the repo root - GitHub only runs workflows from there
├── ci.yml                    # Continuous Integration
└── cd.yml                    # Continuous Delivery / Deployment
```

## CI vs CD

| | Continuous Integration | Continuous Delivery | Continuous Deployment |
| --- | --- | --- | --- |
| Question it answers | *Does this change break anything?* | *Is this change ready to release?* | *Release it.* |
| Trigger | Every push and pull request | Merge to the main branch | Merge to the main branch |
| Does | Build, lint, unit test, build the image | Produce a versioned, deployable artefact; deploy to staging | Deploy to production automatically |
| Ends with | ✅ / ❌ on the commit | An artefact ready to ship, often behind a **manual approval** | Running in production |
| Feedback time | Minutes | Minutes to hours | Minutes |

**CI** keeps the main branch always buildable by integrating small changes
often and verifying each one automatically. **CD** takes a verified build and
makes releasing it routine. *Delivery* stops at a human approval gate;
*Deployment* removes the gate. In this project, `cd.yml` deploys to the
`production` **environment**. GitHub can require a reviewer on that
environment, which turns Continuous Deployment into Continuous Delivery
without changing the workflow.

## The pipeline

```text
 developer
    │ git push / pull request
    ▼
┌──────────────────────────────── ci.yml ─────────────────────────────────┐
│                                                                         │
│  job: build-and-test   (matrix: Node 20, Node 22 - run in parallel)     │
│    checkout → setup-node → syntax check → unit tests → upload artifact  │
│                    │                                                    │
│                    ▼  needs: build-and-test                             │
│  job: docker-build                                                      │
│    checkout → buildx → build image → smoke test (curl /healthz, /, /sum)│
│             → docker save → upload image artifact                       │
└─────────────────────────────────────────────────────────────────────────┘
    │ merge to main
    ▼
┌──────────────────────────────── cd.yml ─────────────────────────────────┐
│  job: push-image                                                        │
│    checkout → buildx → login to GHCR (GITHUB_TOKEN) → metadata (tags)   │
│             → build & push → job summary                                │
│                    │                                                    │
│                    ▼  needs: push-image   environment: production       │
│  job: deploy                                                            │
│    checkout → setup-kubectl → render manifest with new image → apply    │
└─────────────────────────────────────────────────────────────────────────┘
```

## GitHub Actions concepts, mapped to this project

| Concept | What it is | Where it is used here |
| --- | --- | --- |
| **Workflow** | A YAML file in `.github/workflows/` describing an automated process | `ci.yml`, `cd.yml` |
| **Event / trigger** | What starts a workflow | `on: push` (filtered by `paths`), `pull_request`, `workflow_dispatch` (manual button) |
| **Job** | A group of steps that runs on **one** runner. Jobs run in parallel unless linked with `needs` | `build-and-test`, `docker-build`, `push-image`, `deploy` |
| **Step** | A single shell command (`run:`) or a reusable action (`uses:`), run in order inside a job | `npm test`, `actions/checkout@v4` |
| **Action** | A reusable, versioned step published by GitHub or the community | `actions/setup-node`, `docker/build-push-action` |
| **Runner** | The machine executing a job. GitHub-hosted runners are fresh VMs, destroyed after each job | `runs-on: ubuntu-latest` |
| **Matrix** | Run one job across several parameter combinations | Node 20 **and** 22 in parallel |
| **`needs`** | A dependency between jobs, which forms the pipeline graph | `docker-build` needs `build-and-test` |
| **Secrets** | Encrypted values injected at runtime and masked in logs | `secrets.GITHUB_TOKEN` to log in to GHCR; `secrets.KUBE_CONFIG` for a real cluster |
| **Permissions** | The scopes granted to `GITHUB_TOKEN` — least privilege | `contents: read`, `packages: write` |
| **Artifacts** | Files produced by a job and kept after it ends — the only way to pass files between jobs | Test reports (TAP), the saved Docker image |
| **Cache** | Reuse of dependencies and layers between runs | `cache-from/to: type=gha` for Docker layers |
| **Environment** | A deployment target with its own secrets and protection rules | `environment: production` |
| **Job summary** | Markdown written to `$GITHUB_STEP_SUMMARY`, shown on the run page | Image tag and digest |

### Secrets — how they are handled

- `GITHUB_TOKEN` is created automatically for every run, scoped by the
  `permissions:` block and expired when the job ends. No setup is needed.
- Anything else (a Docker Hub token, a kubeconfig) goes in **Settings →
  Secrets and variables → Actions**, and is referenced as
  `${{ secrets.NAME }}`. Values are masked as `***` in the logs.
- Secrets are **not** passed to workflows triggered from forks, which stops a
  malicious pull request from exfiltrating them.
- Never `echo` a secret, and never write it to an artifact.

### Artifacts — what is produced

| Artifact | Job | Contents |
| --- | --- | --- |
| `test-results-node20`, `test-results-node22` | build-and-test | TAP test reports, uploaded even when tests fail (`if: always()`) |
| `docker-image` | docker-build | The built image as `image.tar.gz` |

## The application

| Endpoint | Response |
| --- | --- |
| `GET /` | `{"message":"Hello World from the CI/CD pipeline","version":"1.0.0"}` |
| `GET /healthz` | `{"status":"ok"}` — liveness |
| `GET /readyz` | `{"status":"ready"}` — readiness |
| `GET /sum?a=2&b=3` | `{"a":2,"b":3,"sum":5}` — 400 on non-numeric input |

The Dockerfile has three stages. **`test` runs the unit tests inside the
build**, and the runtime stage copies a marker file from it, so BuildKit cannot
skip the tests: if a test fails, no image is produced. The final image runs as
the unprivileged `node` user and has a `HEALTHCHECK`.

## Build and test — executed

Run locally on Windows 11 + Docker Desktop. Full output is in
[EVIDENCE.md](EVIDENCE.md).

```text
$ npm test
✔ sum adds two numbers
✔ GET / returns the greeting and a version
✔ GET /healthz reports ok
✔ GET /readyz reports ready
✔ GET /sum adds query parameters
✔ GET /sum rejects non-numeric input
✔ unknown path returns 404
ℹ tests 7   ℹ pass 7   ℹ fail 0

$ docker build -t yatri-cicd-demo:local .
#10 [test 6/6] RUN npm test && touch /app/.tests-passed
#10 0.758 # tests 7
#10 0.759 # pass 7
#10 0.759 # fail 0
#12 [runtime 3/6] COPY --from=test /app/.tests-passed /tmp/.tests-passed
...
#16 naming to docker.io/library/yatri-cicd-demo:local done

$ curl http://localhost:3300/
{"message":"Hello World from the CI/CD pipeline","version":"1.0.0"}

$ curl "http://localhost:3300/sum?a=20&b=22"
{"a":20,"b":22,"sum":42}

$ docker exec yatri-smoke id
uid=1000(node) gid=1000(node) groups=1000(node)
```

Two real bugs were caught and fixed while building this:

1. **`COPY --from=deps /app/node_modules` failed** — with zero dependencies,
   `npm install` creates no `node_modules` directory. Fixed with
   `mkdir -p node_modules` in the deps stage.
2. **The test stage would silently never run** — BuildKit only builds the
   stages the target depends on, and nothing depended on `test`. Fixed by
   copying `.tests-passed` from it into the runtime stage. The
   `.dockerignore` also excluded `test/`, which would have broken that stage,
   so that was removed as well.

> **Later change, from Session 17:** the image scan found 10 HIGH CVEs inside
> npm, which ships in the base image but is never used at runtime. The runtime
> stage now deletes npm, npx, yarn and corepack, and a committed
> `package-lock.json` lets the deps stage use `npm ci`. The evidence above was
> captured before that change; see
> [16-cicd-devsecops/EVIDENCE.md](../16-cicd-devsecops/EVIDENCE.md#5b-remediation---remove-npmyarncorepack-from-the-runtime-image-rescan)
> for the before/after scans.

## Deploying to Kubernetes

The CD job renders `kubernetes/deployment.yaml` with the image that was just
pushed and applies it. The same manifests run on minikube. The results are in
[EVIDENCE.md](EVIDENCE.md#4-deployed-to-kubernetes-minikube):

```bash
minikube image load yatri-cicd-demo:latest
kubectl apply -f kubernetes/
kubectl rollout status deploy/yatri-cicd-demo
curl http://$(minikube ip):30080/
```

## Running the pipeline on GitHub

The workflows live at the repository root (`.github/workflows/`), which is the
only place GitHub looks for them. They trigger on pushes that touch
`15-cicd-github-actions/**`, or manually:

1. Push the repository: `git push origin main`.
2. Open **Actions → CI** — the `build-and-test` matrix and `docker-build` run.
3. Open **Actions → CD** — the image is pushed to
   `ghcr.io/<owner>/devops_hw/yatri-cicd-demo` and the deploy job renders the
   manifests.
4. To deploy to a real cluster, add a `KUBE_CONFIG` secret (base64 kubeconfig)
   and uncomment the kubeconfig step in `cd.yml`.
5. Optional: under **Settings → Environments → production**, add a required
   reviewer to turn on manual approval before deploy.

> **Screenshots:** the GitHub Actions run pages (green checks, the job graph,
> artifacts and summary) only exist once the workflows have run on GitHub.
> Capture them after pushing.
