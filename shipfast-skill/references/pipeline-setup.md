# Pipeline Setup — From Zero to Production CI/CD

## CI Tool Selection Matrix

| Criteria | GitHub Actions | Jenkins | GitLab CI | CircleCI |
|----------|---------------|---------|-----------|----------|
| **Best for** | GitHub-hosted projects | Self-hosted, complex pipelines | GitLab ecosystem | Speed, parallelism |
| **Setup effort** | Minimal (YAML in repo) | High (server + plugins) | Minimal (YAML in repo) | Low |
| **Pricing** | Free for public repos, 2000 min/mo private | Free (self-hosted) | 400 min/mo free | 6000 min/mo free |
| **Runner** | GitHub-hosted + self-hosted | Self-hosted | GitLab-hosted + self-hosted | Cloud + self-hosted |
| **Caching** | Built-in (actions/cache) | Plugin-based | Built-in | Built-in |
| **Secrets** | Encrypted at repo/org level | Credentials plugin | CI/CD variables | Project/env variables |
| **Community** | Massive (marketplace) | Large (plugins) | Large | Medium |

**Recommendation rules**:
- GitHub-hosted code → GitHub Actions (zero infra overhead)
- On-premise/air-gapped → Jenkins
- Already on GitLab → GitLab CI
- Mac/iOS builds → CircleCI or self-hosted Mac runners

## Pipeline Architecture Principles

1. **Fast feedback** — lint and unit tests should complete in <5 minutes
2. **Idempotency** — re-running the pipeline with same inputs produces same outputs
3. **Isolation** — one pipeline run doesn't affect another
4. **Least privilege** — each stage gets only the permissions it needs
5. **Observability** — every failure has a clear log and notification

## Standard Stage Design

```
Push → Lint → Unit Test → Build → Integration Test → Push Artifact → Deploy Staging → Deploy Prod
          ↘ Type Check ↗        ↘ Security Scan ↗        ↘ Smoke Test ↗
```

### Stage Purposes

| Stage | Duration Target | Blocks On Failure |
|-------|----------------|-------------------|
| **Lint** | <1 min | Yes — fail fast |
| **Unit Test** | <5 min | Yes |
| **Type Check** | <2 min | Yes |
| **Build** | <10 min | Yes |
| **Security Scan** | <5 min | Warnings only (non-blocking in dev) |
| **Integration Test** | <15 min | Yes |
| **Push Artifact** | <3 min | Yes |
| **Deploy Staging** | <5 min | No (manual trigger if needed) |
| **Smoke Test** | <2 min | Yes — but auto-rollback, not block |
| **Deploy Prod** | <5 min | Manual approval gate |

## Branch Strategy Integration

### GitFlow + CI/CD

```
feature/* → build + unit test
develop   → build + test + deploy to dev
release/* → build + test + deploy to staging
main      → deploy to prod (manual approval)
hotfix/*  → build + test + deploy to staging → fast-track to prod
```

### Trunk-Based Development + CI/CD

```
main ← short-lived branches (max 1 day)
  → push to any branch: lint + test + build
  → merge to main: lint + test + build + deploy staging
  → tag on main: deploy prod (auto with rollback)
```

### GitHub Flow + CI/CD

```
feature branch → lint + test + build + preview env
main           → deploy staging (on merge)
Release tag    → deploy prod
```

## Repository Structure Conventions

```
project/
├── .github/workflows/   # GitHub Actions workflows
├── Jenkinsfile          # Jenkins pipeline (at repo root)
├── Dockerfile           # App container
├── docker-compose.yml   # Local dev + CI integration tests
├── k8s/                 # Kubernetes manifests
│   ├── base/            # Kustomize base
│   └── overlays/        # Environment overlays
│       ├── dev/
│       ├── staging/
│       └── prod/
├── scripts/             # CI helper scripts
│   ├── health-check.sh
│   └── deploy.sh
└── Makefile             # Unified entry: make lint, make test, make build
```

## Artifact Management

| Artifact Type | Registry | Tag Strategy |
|--------------|----------|--------------|
| Docker image | ghcr.io / Docker Hub / ECR / ACR | `git-sha`, `semver`, `latest` |
| npm package | npm registry / GitHub Packages | semver |
| Python wheel | PyPI / private index | semver |
| Go binary | GitHub Releases / S3 | semver |
| Helm chart | OCI registry / ChartMuseum | semver (match app version) |

**Golden rule**: Pin by digest (`image@sha256:abc...`) in production, not by tag.

## Notification Setup

**Minimum**: CI failures notify the committer via email or Slack.

**Recommended**: Dedicated `#ci-alerts` Slack/Teams channel:
- Build/deploy failures: immediate notification
- Deploy successes: notification with changelog link
- Pipeline duration anomalies: weekly summary

### Slack Notification (GitHub Actions)

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v2
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK }}
    webhook-type: incoming-webhook
    payload: |
      {
        "text": ":x: Build failed on ${{ github.ref_name }}\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View run>"
      }
  if: failure()
```

## Pipeline as Code Best Practices

1. **Keep workflows DRY** — use reusable workflows or shared actions
2. **Version pin actions** — `@v3`, not `@main` or `@latest`
3. **Timeouts** — every job needs `timeout-minutes`
4. **Concurrency** — cancel redundant runs:
   ```yaml
   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: true
   ```
5. **Fail fast** — put quick checks (lint, typecheck) before slow ones (integration tests)
6. **Matrix builds** — test across OS/version combos in parallel

## First Pipeline Checklist

Before declaring your CI/CD pipeline "done":

- [ ] Lint step catches style issues before build
- [ ] Tests run and fail the pipeline when broken
- [ ] Build produces a versioned artifact
- [ ] Secrets are in CI config, not in code
- [ ] Docker image pushed to registry with proper tags
- [ ] Deploy succeeded at least once end-to-end
- [ ] Rollback procedure tested
- [ ] Notifications configured for failures
- [ ] Branch protection rules enforce CI passing before merge
