#!/usr/bin/env bash
# Environment Validator — Pre-deployment check for CI/CD pipelines
# Usage: ./env-validator.sh [--strict] [--env-file .env.example]
# Verifies required env vars are present, non-empty, and correctly formatted.
set -euo pipefail

STRICT=false
ENV_FILE=".env.example"
EXIT_CODE=0

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --strict) STRICT=true; shift ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Environment Validator ==="
echo "Env file: $ENV_FILE"
echo "Mode:     $([ "$STRICT" = true ] && echo 'strict (fail on warnings)' || echo 'lenient')"
echo "=============================="

declare -A ERRORS
declare -A WARNINGS

# Check 1: Required environment variables
check_required_vars() {
  local required_vars=(
    "NODE_ENV"
    "DATABASE_URL"
    "PORT"
  )

  # Add vars from --env-file if provided
  if [[ -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
      # Only check vars that are set (have a value in .env.example)
      if [[ -n "${!key:-}" ]]; then
        required_vars+=("$key")
      fi
    done < "$ENV_FILE"
  fi

  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      ERRORS["$var"]="Not set"
    fi
  done
}

# Check 2: URL format validation
check_url_format() {
  local url_vars=("DATABASE_URL" "API_URL" "REDIS_URL")
  for var in "${url_vars[@]}"; do
    local value="${!var:-}"
    [[ -z "$value" ]] && continue
    if [[ ! "$value" =~ ^https?:// ]] && [[ ! "$value" =~ ^[a-z]+:// ]]; then
      ERRORS["$var"]="Invalid URL format: $value"
    fi
  done
}

# Check 3: Port range validation
check_port_range() {
  local value="${PORT:-}"
  [[ -z "$value" ]] && return
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]] || [[ "$value" -gt 65535 ]]; then
    ERRORS["PORT"]="Invalid port: $value (must be 1-65535)"
  fi
}

# Check 4: Numeric range validation
check_numeric_ranges() {
  local value

  value="${NODE_MEMORY_LIMIT:-0}"
  if [[ "$value" -lt 64 ]]; then
    WARNINGS["NODE_MEMORY_LIMIT"]="Low memory limit: ${value}MB (recommend >= 128)"
  fi
}

# Check 5: Boolean values
check_booleans() {
  local bool_vars=("DEBUG" "ENABLE_CORS" "ENABLE_RATE_LIMIT")
  for var in "${bool_vars[@]}"; do
    local value="${!var:-}"
    [[ -z "$value" ]] && continue
    value_lower=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    if [[ "$value_lower" != "true" && "$value_lower" != "false" && "$value_lower" != "1" && "$value_lower" != "0" ]]; then
      WARNINGS["$var"]="Unexpected boolean value: $value (expected true/false/1/0)"
    fi
  done
}

# Check 6: Secret leakage check (warn if env var looks like it contains a real secret)
check_secret_hygiene() {
  for var in $(compgen -v); do
    local value="${!var}"
    # Skip empty or short values
    [[ -z "$value" || ${#value} -lt 20 ]] && continue
    # Check for patterns that look like JWT tokens, API keys, etc
    if [[ "$value" =~ ^eyJ[a-zA-Z0-9_-]+\. ]] || \
       [[ "$value" =~ ^sk-[a-zA-Z0-9]{32,} ]] || \
       [[ "$value" =~ ^ghp_[a-zA-Z0-9]{36,} ]]; then
      WARNINGS["$var"]="Value looks like it might be a real secret — ensure it's set via CI, not committed"
    fi
  done
}

# Run all checks
check_required_vars
check_url_format
check_port_range
check_numeric_ranges
check_booleans
check_secret_hygiene

# Report
echo ""
echo "--- Results ---"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "❌ ERRORS (${#ERRORS[@]}):"
  for var in "${!ERRORS[@]}"; do
    echo "  - $var: ${ERRORS[$var]}"
  done
  EXIT_CODE=1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "⚠️  WARNINGS (${#WARNINGS[@]}):"
  for var in "${!WARNINGS[@]}"; do
    echo "  - $var: ${WARNINGS[$var]}"
  done
  if [[ "$STRICT" == true ]]; then
    EXIT_CODE=1
  fi
fi

if [[ ${#ERRORS[@]} -eq 0 && ${#WARNINGS[@]} -eq 0 ]]; then
  echo "✓ All checks passed"
fi

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "✓ Environment validation passed"
else
  echo "❌ Environment validation failed"
fi

exit $EXIT_CODE
