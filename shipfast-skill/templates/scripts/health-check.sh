#!/usr/bin/env bash
# Health Check Script — HTTP endpoint poller for CI/CD pipelines
# Usage: ./health-check.sh [URL] [--retries N] [--interval S] [--timeout S]
# Exit codes: 0 = healthy, 1 = failed after all retries

set -o pipefail

# Defaults
URL="${1:-http://localhost:3000/health}"
RETRIES=10
INTERVAL=5
TIMEOUT=10
EXPECTED_STATUS="200"
CONTAINS=""

# Parse optional flags
shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --retries) RETRIES="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --status) EXPECTED_STATUS="$2"; shift 2 ;;
    --contains) CONTAINS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Health Check ==="
echo "URL:      $URL"
echo "Retries:  $RETRIES"
echo "Interval: ${INTERVAL}s"
echo "Timeout:  ${TIMEOUT}s"
echo "Expected: HTTP $EXPECTED_STATUS"
[[ -n "$CONTAINS" ]] && echo "Contains: $CONTAINS"
echo "===================="

for i in $(seq 1 "$RETRIES"); do
  # curl options:
  #   -s: silent (no progress meter)
  #   -o /dev/null: discard body (unless --contains is set)
  #   -w "%{http_code}": print only status code
  #   --max-time: total time allowed for request
  #   -f: fail silently on HTTP errors (4xx/5xx)

  if [[ -n "$CONTAINS" ]]; then
    BODY=$(curl -s --max-time "$TIMEOUT" "$URL" 2>&1)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>&1)
  else
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>&1)
  fi

  if [[ "$STATUS" == "$EXPECTED_STATUS" ]]; then
    if [[ -n "$CONTAINS" ]] && [[ "$BODY" != *"$CONTAINS"* ]]; then
      echo "[$i/$RETRIES] HTTP $STATUS but body does not contain '$CONTAINS' — retrying in ${INTERVAL}s..."
    else
      echo "[$i/$RETRIES] ✓ Healthy — HTTP $STATUS"
      exit 0
    fi
  else
    echo "[$i/$RETRIES] HTTP $STATUS (expected $EXPECTED_STATUS) — retrying in ${INTERVAL}s..."
  fi

  if [[ $i -lt $RETRIES ]]; then
    sleep "$INTERVAL"
  fi
done

echo "ERROR: Health check failed after $RETRIES attempts"
exit 1
