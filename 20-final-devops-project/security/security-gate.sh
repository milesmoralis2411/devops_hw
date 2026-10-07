#!/usr/bin/env sh
# Security gate: fail the pipeline when a report crosses the policy line.
# Usage: security-gate.sh <trivy-image.json> [max_critical] [max_high]
set -eu
REPORT="$1"; MAX_CRIT="${2:-0}"; MAX_HIGH="${3:-5}"
CRIT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$REPORT")
HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$REPORT")
echo "Policy : CRITICAL <= $MAX_CRIT, HIGH <= $MAX_HIGH (fixable only)"
echo "Found  : CRITICAL = $CRIT, HIGH = $HIGH"
if [ "$CRIT" -gt "$MAX_CRIT" ] || [ "$HIGH" -gt "$MAX_HIGH" ]; then
  echo "SECURITY GATE: FAILED"; exit 1
fi
echo "SECURITY GATE: PASSED"
