# CI/CD Security — Supply Chain, Secrets & Compliance

## Secrets Management Hierarchy

```
Avoid plain-text env vars
  → Use CI secret manager (GitHub Secrets, Jenkins Credentials)
  → Use sealed secrets at rest (SealedSecrets, SOPS)
  → Use external secret stores (Vault, AWS Secrets Manager, GCP Secret Manager)
  → Rotate automatically (short-lived credentials from OIDC)
```

WARNING: Never commit secrets to git — even in private repos. Once a secret touches git, consider it compromised.

### GitHub Actions — OIDC (no long-lived secrets)

```yaml
# Authenticate to AWS without storing AWS credentials
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions
    aws-region: us-east-1

# Authenticate to GCP
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/123/locations/global/workloadIdentityPools/github/providers/github'
    service_account: 'github-actions@my-project.iam.gserviceaccount.com'
```

### Secret Detection in CI

```yaml
# trufflehog — scan for secrets before build
- uses: trufflesecurity/trufflehog-action@v1
  with:
    path: ./

# gitleaks — alternative
- uses: gitleaks/gitleaks-action@v2
```

Add to `.gitleaks.toml`:
```toml
[allowlist]
  description = "False positives"
  paths = [
    '''test/fixtures/.*''',
    '''.*\.test\.ts''',
  ]
```

## CI/CD Pipeline Privilege Minimization

### GitHub Actions — Least Privilege Permissions

```yaml
permissions:
  contents: read        # Only clone repo
  id-token: write       # Only if using OIDC
  # Everything else: none (implicit deny)
```

Bad:
```yaml
permissions: write-all  # NEVER do this
```

### Jenkins — Service Account

- Create a dedicated service account per pipeline, not shared admin accounts
- Limit K8s RBAC to specific namespace
- Limit cloud IAM to specific resources

### Docker — Non-Root in CI

```yaml
# docker-compose.ci.yml
services:
  app:
    build: .
    user: "1000:1000"  # Non-root
    security_opt:
      - no-new-privileges:true
    read_only: true    # Read-only root filesystem
    tmpfs:
      - /tmp
```

## Image Signing & Verification

### Cosign (Sigstore)

```bash
# Sign an image
cosign sign --key cosign.key ghcr.io/org/my-app:${GITHUB_SHA}

# Verify in deployment
cosign verify \
  --key cosign.pub \
  ghcr.io/org/my-app:${GITHUB_SHA}
```

```yaml
# In GitHub Actions
- uses: sigstore/cosign-installer@v3
- run: cosign sign --yes --key env://COSIGN_PRIVATE_KEY ${{ steps.build.outputs.image }}
  env:
    COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
```

### Admission Controller (verify at deploy time)

Deploy Kyverno or Connaisseur to enforce signature verification before K8s admits the pod:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signature
      match:
        resources:
          kinds:
            - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/org/*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      ...
                      -----END PUBLIC KEY-----
```

## SBOM Generation (Software Bill of Materials)

```yaml
# Generate SBOM with Syft
- uses: anchore/sbom-action@v0
  with:
    image: ${{ steps.build.outputs.image }}
    format: spdx-json
    output-file: sbom.spdx.json

- uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: sbom.spdx.json
```

## Dependency Scanning

### Dependabot

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "security"

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Renovate (alternative, more configurable)

```json
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "automergeType": "pr"
    }
  ]
}
```

## Pipeline Injection Prevention

### The Danger: `pull_request_target` + checkout

```yaml
# DANGEROUS — runs untrusted code with repo secrets!
on:
  pull_request_target

jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # Untrusted code!
      - run: npm run build  # Injects malicious code!
```

### The Fix: Separate workflows

```yaml
# Safe: workflow 1 runs with read-only permissions
on:
  pull_request

permissions:
  contents: read

jobs:
  build:
    steps:
      - uses: actions/checkout@v4  # No ref override
      - run: npm test
```

```yaml
# Safe: workflow 2 adds label, requires explicit approval
on:
  pull_request_target:
    types: [labeled]

jobs:
  comment:
    if: github.event.label.name == 'safe-to-test'
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              ...context.repo,
              issue_number: context.issue.number,
              body: 'Approved for testing'
            })
```

**Rule of thumb**: Never check out PR code in a workflow triggered by `pull_request_target`.

## Audit Logging & Drift Detection

### GitHub Actions Audit Log

```bash
# Fetch audit log events for Actions
gh api orgs/<org>/audit-log --paginate -q '.[] | select(.action | startswith("workflows."))'
```

### K8s Drift Detection (ArgoCD)

ArgoCD continuously reconciles desired state vs actual state — drift is auto-detected and can be auto-corrected.

### Terraform Drift Detection

```yaml
- name: Check infrastructure drift
  run: |
    terraform plan -detailed-exitcode
    # Exit code 0 = no changes, 1 = error, 2 = drift detected
```

## Compliance Automation (Quick Wins)

| Compliance Requirement | CI/CD Automation |
|----------------------|-----------------|
| SOC2: Change management | Require PR approvals, pipeline must pass, deployment audit log |
| SOC2: Access control | Least-privilege CI service accounts, no shared credentials |
| PCI-DSS: Vulnerability scanning | Trivy/Snyk in pipeline, block HIGH/CRITICAL |
| PCI-DSS: Change detection | All infra changes through git + pipeline, detect drift |
| HIPAA: Audit trail | SBOM generation, signed commits, immutable build logs |

## Pre-Commit Security Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit — block secrets from being committed

# Check for common secret patterns
if git diff --cached | grep -E '(password|secret|token|api.?key)\s*[:=]\s*["'']?[^\s"''$]' > /dev/null 2>&1; then
    echo "ERROR: Potential secret detected in diff. Use environment variables or CI secrets."
    exit 1
fi

# Run gitLeaks
if command -v gitleaks &> /dev/null; then
    gitleaks protect --staged --no-banner --verbose
    if [ $? -ne 0 ]; then
        echo "ERROR: gitleaks found secrets in staged changes."
        exit 1
    fi
fi
```
