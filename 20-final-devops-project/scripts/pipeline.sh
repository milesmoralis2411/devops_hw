#!/usr/bin/env bash
# Local run of the same pipeline as .github/workflows/pipeline.yml:
#
#   test -> SAST -> SCA -> secret scan -> build -> image scan -> security gate
#        -> push to registry -> GitOps commit (Argo CD deploys it)
#
# Usage:  scripts/pipeline.sh <version-tag> <gitops-working-copy>
#   <gitops-working-copy> is a clone of the platform repo that Argo CD watches.
#
# Needs: bash, node 20+, docker, git, jq. Scanners run as containers, so no
# local Trivy/Gitleaks install is needed. Semgrep is used if installed.
set -euo pipefail

TAG="${1:?usage: pipeline.sh <tag> <gitops-repo-dir>}"
GITOPS_DIR="${2:?usage: pipeline.sh <tag> <gitops-repo-dir>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${REGISTRY:-localhost:5000}"            # what we push to (host side)
PULL_REGISTRY="${PULL_REGISTRY:-host.minikube.internal:5000}"  # what the cluster pulls from
IMAGE="yatri-trips"
export MSYS_NO_PATHCONV=1                          # keep /paths intact on Git Bash
# Native Windows programs (docker, jq) need C:/... paths on Git Bash; elsewhere this is just pwd.
WIN_ROOT="$(cd "$ROOT" && (pwd -W 2>/dev/null || pwd))"

stage() { printf '\n========== %s ==========\n' "$*"; }

stage "1/8 Unit tests"
(cd "$ROOT/application" && npm run --silent lint && npm test 2>&1 | grep -E '^(✔|✖|ℹ (tests|pass|fail))')

stage "2/8 SAST"
if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --metrics=off --quiet --error --severity ERROR \
    --config p/javascript --config "$WIN_ROOT/security/semgrep.yml" "$WIN_ROOT/application/src"
  echo "semgrep: no ERROR-severity findings"
else
  echo "semgrep not installed locally - SAST runs in the GitHub Actions job (semgrep/semgrep container)"
fi

stage "3/8 SCA + IaC scanning - dependencies and misconfigurations"
(cd "$ROOT/application" && npm audit --audit-level=high 2>&1 | tail -1)
# Whole project: app deps, Dockerfile, Helm, rendered manifests, monitoring,
# GitOps and Terraform. Accepted risks live in security/.trivyignore.
docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v "$WIN_ROOT:/src" aquasec/trivy:0.57.1 fs --quiet \
  --skip-check-update --scanners vuln,misconfig,secret --severity HIGH,CRITICAL \
  --ignorefile /src/security/.trivyignore --exit-code 1 /src \
  && echo "trivy fs: no HIGH/CRITICAL vulnerabilities, misconfigurations or secrets (1 accepted risk in .trivyignore)"

stage "4/8 Secret scanning"
docker run --rm -v "$WIN_ROOT:/repo" zricethezav/gitleaks:v8.21.2 detect --no-git \
  --source /repo --config /repo/security/gitleaks.toml --no-banner --redact --exit-code 1 \
  && echo "gitleaks: no secrets found"

stage "5/8 Build image $IMAGE:$TAG"
docker build -q -f "$WIN_ROOT/docker/Dockerfile" --build-arg APP_VERSION="$TAG" -t "$IMAGE:$TAG" "$WIN_ROOT/application"
docker image inspect "$IMAGE:$TAG" --format 'size={{.Size}} user={{.Config.User}} created={{.Created}}'

stage "6/8 Image scan"
docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.57.1 image --quiet \
  --severity HIGH,CRITICAL --ignore-unfixed --format json "$IMAGE:$TAG" > "$ROOT/.trivy-image.json"
jq -r '.Results[] | "\(.Target): \((.Vulnerabilities // []) | length) HIGH/CRITICAL"' "$WIN_ROOT/.trivy-image.json"

stage "7/8 Security gate"
sh "$ROOT/security/security-gate.sh" "$WIN_ROOT/.trivy-image.json" 0 5
rm -f "$ROOT/.trivy-image.json"

stage "8/8 Push + GitOps deploy"
docker tag "$IMAGE:$TAG" "$REGISTRY/$IMAGE:$TAG"
docker push -q "$REGISTRY/$IMAGE:$TAG"
curl -s "http://$REGISTRY/v2/$IMAGE/tags/list"; echo
VALUES="$GITOPS_DIR/helm/yatri-trips/values-prod.yaml"
sed -i -E "s#^(  repository: ).*#\1$PULL_REGISTRY/$IMAGE   \# lab registry; ECR URL on AWS#" "$VALUES"
sed -i -E "s/^(  tag: ).*/\1\"$TAG\"/" "$VALUES"
if git -C "$GITOPS_DIR" diff --quiet; then
  echo "values-prod.yaml already points at $TAG - image published, nothing to commit"
else
  git -C "$GITOPS_DIR" -c user.name=yatri-ci -c user.email=ci@yatri.local commit -qam "deploy: yatri-trips $TAG"
  git -C "$GITOPS_DIR" push -q origin main
fi
git -C "$GITOPS_DIR" log --oneline -1
echo "pushed - Argo CD will roll out $TAG"
