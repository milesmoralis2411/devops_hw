#!/usr/bin/env bash
# Final troubleshooting challenge: one plausible-looking "release" commit that
# quietly introduces five independent faults into the GitOps repository.
#
# Usage: troubleshooting/inject-faults.sh <gitops-working-copy>
set -euo pipefail
REPO="${1:?usage: inject-faults.sh <gitops-repo-dir>}"
V="$REPO/helm/yatri-trips/values-prod.yaml"
P="$REPO/monitoring/config/prometheus.yml"

# A - bump to a version whose image was never built or pushed
sed -i -E 's/^(  tag: ).*/\1"1.1.0"/' "$V"
# B - "rename" the Secret in values only; the real Secret is still yatri-trips-secret
cat >> "$V" <<'YAML'

secret:
  create: false
  existingSecret: yatri-api-key
YAML
# C - "give it more headroom": 5Gi request blows the namespace ResourceQuota (4Gi)
python - "$V" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"resources:\n  requests:\n    cpu: 100m\n    memory: 96Mi\n  limits:\n    cpu: 500m\n    memory: 256Mi",
           "resources:\n  requests:\n    cpu: 100m\n    memory: 5Gi\n  limits:\n    cpu: 500m\n    memory: 5Gi", s)
open(p, "w").write(s)
PY
# D - typo in the public hostname
sed -i 's/host: yatri-prod.local/host: yatri-prod.locl/' "$V"
# E - typo in a scrape target: kube-state-metrics disappears from Prometheus
sed -i 's/kube-state-metrics.monitoring.svc:8080/kube-state-metric.monitoring.svc:8080/' "$P"

git -C "$REPO" -c user.name="Release Bot" -c user.email=release@yatri.local commit -qam "release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up"
git -C "$REPO" push -q origin main
git -C "$REPO" log --oneline -1
