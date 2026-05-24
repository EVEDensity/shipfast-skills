# CI/CD Workflow Patterns — End-to-End Architecture

## GitFlow CI/CD

```
Branch        CI Trigger         Deploy Target
─────────────────────────────────────────────────
feature/*     lint + test        none (PR check)
develop       lint + test        dev environment
              + build + deploy
release/*     full CI             staging (auto)
              + integration
              + deploy
main          deploy only         production (manual gate)
hotfix/*      full CI + deploy   staging → production (fast-track)
```

**Key rules**:
- `feature/*` branches only need to prove they compile and pass tests
- `develop` is the integration point — catches merge conflicts early
- `release/*` is the pre-prod freeze — only bug fixes, no new features
- `main` stores production history — every commit = a deployable state
- `hotfix/*` branches off `main`, merges back to both `main` and `develop`

**Pros**: Clear separation of concerns, well-understood by teams.
**Cons**: Many long-lived branches, merge complexity, slow feedback on integration issues.

---

## Trunk-Based Development

```
main ← short-lived feature branches (<1 day)

Push to any branch → lint + test + build
Merge to main       → lint + test + build + deploy staging
Tag on main         → deploy production
```

**Key rules**:
- Branches live <1 day (ideally <few hours)
- Feature flags hide in-progress work from users
- All commits to main must pass CI
- No release branches — releases are tags on main

**Pros**: Fastest feedback, minimal merge conflicts, simple pipeline.
**Cons**: Requires feature flag discipline, not suited for versioned on-prem releases.

---

## GitHub Flow

```
feature branch → CI + preview environment (on PR)
main            → CI + deploy staging (on merge)
Release tag     → deploy production
```

**Key rules**:
- Only one long-lived branch: `main`
- Every PR gets a preview environment (optional but recommended)
- Merging to `main` = deploying to staging
- Tags trigger production deploy

**Pros**: Simple, works great with GitHub Actions.
**Cons**: Preview environments add infra cost.

---

## GitOps (ArgoCD / Flux)

```
Developer push → CI (lint, test, build, push image)
                → Update image tag in config repo
ArgoCD/Flux watches config repo
                → Syncs K8s cluster to match desired state
```

**Key rules**:
- Application repo and config repo are separate
- CI pushes to app repo; CD pulls from config repo
- Cluster state is fully declarative in git
- Manual changes to cluster are forbidden (drift detection)

**Directory structure for config repo**:
```
config-repo/
├── apps/
│   ├── my-app/
│   │   ├── base/
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── staging/
│   │       │   └── kustomization.yaml
│   │       └── production/
│   │           └── kustomization.yaml
```

**GitHub Actions → ArgoCD integration**:
```yaml
- name: Update image tag in config repo
  run: |
    git clone https://${{ secrets.PAT }}@github.com/org/config-repo.git
    cd config-repo
    cd apps/my-app/overlays/staging
    kustomize edit set image my-app=${{ steps.build.outputs.image }}
    git commit -am "bump my-app to ${{ github.sha }}"
    git push
```

---

## PR Preview Environments

Every pull request gets an ephemeral, isolated deployment.

```
PR opened    → build image → deploy to preview namespace
PR updated   → redeploy preview
PR merged    → teardown preview namespace
PR closed    → teardown preview namespace
```

**GitHub Actions implementation**:
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build and push
        run: |
          docker build -t my-app:pr-${{ github.event.number }} .
          docker push my-app:pr-${{ github.event.number }}
      - name: Deploy to preview
        run: |
          export NAMESPACE="preview-pr-${{ github.event.number }}"
          kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -f k8s/ -n $NAMESPACE
          kubectl set image deployment/my-app my-app=my-app:pr-${{ github.event.number }} -n $NAMESPACE

  teardown:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    steps:
      - run: kubectl delete namespace preview-pr-${{ github.event.number }} --ignore-not-found
```

**Cost consideration**: Preview environments multiply infra. Use small instances, auto-teardown after 24h, and limit concurrency.

---

## Canary Releases with Argo Rollouts

```
Stable: 90% traffic → Canary: 10% traffic
  → Monitor (error rate, latency, CPU) for 5min
  → Promote: 50% → 100% (auto)
  OR
  → Rollback: 0% canary (auto on metric threshold breach)
```

**Argo Rollout manifest**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 2m}
        - setWeight: 100
```

**Analysis template** (auto-rollback on errors):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
spec:
  metrics:
    - name: error-rate
      interval: 30s
      successCondition: result < 0.01
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            rate(http_requests_total{status=~"5.."}[1m]) /
            rate(http_requests_total[1m])
```

---

## Multi-Service Monorepo CI

Build only what changed, not the entire monorepo on every push.

```
Push → detect changed services → for each changed service:
  → lint → test → build → push image (with service-specific tag)
```

**GitHub Actions path-filtered triggers**:
```yaml
on:
  push:
    paths:
      - 'services/auth/**'
      - 'services/api/**'
```

**Or use a change-detection action**:
```yaml
- uses: dorny/paths-filter@v3
  id: changes
  with:
    filters: |
      auth:
        - 'services/auth/**'
      api:
        - 'services/api/**'

- name: Build auth
  if: steps.changes.outputs.auth == 'true'
  run: cd services/auth && make build

- name: Build api
  if: steps.changes.outputs.api == 'true'
  run: cd services/api && make build
```

---

## Hotfix Workflow

Emergency fix path with bypassed gates but preserved audit trail.

```
hotfix/* branch off main
  → CI: lint + test (required, can't skip)
  → Build + push (required)
  → Deploy staging (optional — can skip if critical)
  → Deploy prod (manual but no approval gate)
  → Post-deploy: merge back to main + develop (required)
  → Create incident ticket with deploy details
```

**Key rule**: The only thing you can skip in a hotfix is the staging validation and the approval gate. Tests and lint are never skippable.

---

## Database Migration in CI/CD

**Pattern**: Run migrations as a separate, reversible job BEFORE deploy.

```
CI pipeline:
  1. Build
  2. Test
  3. Run migration (with timeout, with rollback plan)
  4. Deploy app
  5. Smoke test
```

**Safety rules**:
1. Migrations must be backward-compatible — new code works with old schema
2. Never rename columns in a single deploy — add new column, deploy, remove old column, deploy
3. Always have a rollback migration tested
4. Migration job has a hard timeout (no hanging migrations)
5. Take a DB snapshot before migration in production

**Expansion vs contraction pattern** (zero-downtime):
```
Phase 1 (expand):  Add new column/table, deploy app that writes to both
Phase 2 (migrate): Backfill existing rows
Phase 3 (contract): Deploy app that reads only new column, drop old column
```

---

## Choosing a Pattern

| Situation | Recommended Pattern |
|-----------|-------------------|
| Small team, single service | GitHub Flow + preview envs |
| Enterprise, compliance requirements | GitFlow + approval gates |
| Fast-moving startup | Trunk-based + feature flags |
| K8s-native, platform team | GitOps (ArgoCD) |
| Monorepo, many services | Path-filtered CI + GitOps |
| High-risk deployments | Canary releases with auto-rollback |
| Regulated industry | GitFlow + SBOM + deployment approvals |
