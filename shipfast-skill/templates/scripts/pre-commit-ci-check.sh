#!/usr/bin/env bash
# Pre-Commit CI Check — Run locally before pushing to avoid red pipelines
# Usage: ./pre-commit-ci-check.sh [--skip-build] [--skip-test]
# Installs as git hook: ln -s ../../scripts/pre-commit-ci-check.sh .git/hooks/pre-commit
set -euo pipefail

SKIP_BUILD=false
SKIP_TEST=false
EXIT_CODE=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-test) SKIP_TEST=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Pre-Commit CI Check ==="
echo ""

# Auto-detect project type
detect_project() {
  if [[ -f "package.json" ]]; then
    echo "node"
  elif [[ -f "go.mod" ]]; then
    echo "go"
  elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
    echo "python"
  else
    echo "unknown"
  fi
}

PROJECT_TYPE=$(detect_project)
echo "Detected project: $PROJECT_TYPE"

run_step() {
  local name="$1"
  local cmd="$2"
  echo -n "[$name] "
  if eval "$cmd" 2>&1; then
    echo "  ✓ PASS"
    return 0
  else
    echo "  ❌ FAIL"
    EXIT_CODE=1
    return 1
  fi
}

case "$PROJECT_TYPE" in
  node)
    echo ""
    echo "--- Node.js Checks ---"

    # Lint
    if command -v npx &>/dev/null && npx --no-install eslint --help &>/dev/null 2>&1; then
      run_step "lint" "npx eslint . --max-warnings=0" || true
    fi

    # Format check
    if command -v npx &>/dev/null && npx --no-install prettier --help &>/dev/null 2>&1; then
      run_step "format" "npx prettier --check 'src/**/*.{ts,tsx,js,jsx}' 2>/dev/null || npx prettier --check '**/*.{ts,tsx,js,jsx}'" || true
    fi

    # Type check (TypeScript)
    if [[ -f "tsconfig.json" ]]; then
      run_step "typecheck" "npx tsc --noEmit" || true
    fi

    # Unit tests
    if [[ "$SKIP_TEST" != true ]] && [[ -f "package.json" ]]; then
      if grep -q '"test"' package.json; then
        run_step "test" "npm test" || true
      fi
    fi

    # Build check
    if [[ "$SKIP_BUILD" != true ]] && [[ -f "package.json" ]]; then
      if grep -q '"build"' package.json; then
        run_step "build" "npm run build" || true
      fi
    fi
    ;;

  python)
    echo ""
    echo "--- Python Checks ---"

    # Lint (ruff)
    if command -v ruff &>/dev/null; then
      run_step "lint" "ruff check ." || true
    fi

    # Format check (black)
    if command -v black &>/dev/null; then
      run_step "format" "black --check ." || true
    fi

    # Type check
    if command -v mypy &>/dev/null; then
      run_step "typecheck" "mypy src/ 2>/dev/null || mypy ." || true
    fi

    # Tests
    if [[ "$SKIP_TEST" != true ]] && command -v pytest &>/dev/null; then
      run_step "test" "pytest --tb=short" || true
    fi
    ;;

  go)
    echo ""
    echo "--- Go Checks ---"

    run_step "vet" "go vet ./..." || true
    run_step "fmt" "test -z \"$(gofmt -l .)\"" || true

    # Lint
    if command -v golangci-lint &>/dev/null; then
      run_step "lint" "golangci-lint run --timeout=5m" || true
    fi

    # Tests
    if [[ "$SKIP_TEST" != true ]]; then
      run_step "test" "go test -race -count=1 ./..." || true
    fi

    # Build check
    if [[ "$SKIP_BUILD" != true ]]; then
      run_step "build" "go build ./..." || true
    fi
    ;;

  *)
    echo "Unknown project type — no checks configured"
    echo "Add custom checks for your project type to this script"
    ;;
esac

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "✓ All checks passed — ready to push"
else
  echo "❌ Some checks failed — fix before pushing"
fi

exit $EXIT_CODE
