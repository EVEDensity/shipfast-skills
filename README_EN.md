# ShipFast

<p align="center">
  <strong>Ship code from commit to production, fast.</strong>
</p>

<p align="center">
  <a href="README.md">Home</a>
  ·
  <a href="README_CN.md">中文</a>
  ·
  <a href="#top">English</a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#why-this-skill">Pain Points</a> ·
  <a href="#feature-matrix">Features</a> ·
  <a href="#five-core-workflows">Workflows</a> ·
  <a href="#directory-structure">Structure</a> ·
  <a href="#template-catalog">Templates</a>
</p>

---

## Why This Skill?

In daily development, do you often face:

- Deployment failures with opaque logs you can't decipher
- Starting CI/CD from scratch — writing YAML through trial and error
- Pipelines taking 20 minutes with no idea how to optimize
- Multi-environment deploys managed by manually editing configs
- Docker images at 2GB, builds taking 10 minutes every time

**This skill solves all of the above in one shot.**

## Core Value

Targeting high-frequency developer pain points with **copy-paste-ready** scripts, configs, and troubleshooting guides. Covers Git, Jenkins, Docker, Kubernetes, and GitHub Actions — serving individual devs, teams, and production deployment scenarios alike.

## Quick Start

### 1. Install

Place the `shipfast/` directory in your Claude Code skills path.

### 2. Trigger

Describe your problem or need directly in Claude Code:

```
/ My GitHub Actions deploy keeps failing with Permission denied
/ Set up CI/CD for this Node.js project
/ How do I shrink my Docker image?
/ How to set up multi-environment (dev/staging/prod) deployment?
/ My K8s Pod is stuck in CrashLoopBackOff — help!
```

The skill auto-detects the context and follows structured workflows to deliver solutions.

## Feature Matrix

| Tool | Setup | Troubleshoot | Optimize | Templates |
|------|:-----:|:------------:|:--------:|:---------:|
| **GitHub Actions** | ✓ | ✓ | ✓ | 8 YAML workflows |
| **Jenkins** | ✓ | ✓ | ✓ | 3 Jenkinsfiles |
| **Docker** | ✓ | ✓ | ✓ | 4 Dockerfiles + Compose + .dockerignore |
| **Kubernetes** | ✓ | ✓ | ✓ | 7 YAML manifests |
| **Shell Scripts** | — | ✓ | ✓ | 5 production scripts |
| **Security** | ✓ | ✓ | — | Secret detection + image scan + SBOM |

## Five Core Workflows

### 1. Deployment Failure Diagnosis

```
Failure reported → Identify tool & stage → Match error pattern → Deliver fix + verify command
```

Covers 20+ common errors across GitHub Actions / Docker / K8s. Each entry follows: Symptom → Root Cause → Fix → Verify.

### 2. CI/CD Setup from Scratch

```
Assess project → Recommend CI tool → Select templates → Customize {{PLACEHOLDERS}} → Guide first run
```

Supports Node.js / Python / Go / Java stacks.

### 3. Pipeline Performance Optimization

```
Analyze config → Identify bottlenecks (cache/parallelism/Docker layers) → Provide before/after diff → Apply high-impact items first
```

### 4. Multi-Environment Deployment

```
Map environments → Design promotion flow → Provide multi-env-deploy.yml → Configure approval gates & secret isolation
```

### 5. Application Containerization

```
Analyze stack → Generate Dockerfile → Add CI build/push pipeline → Wire up K8s deployment
```

## Directory Structure

```
shipfast/
├── SKILL.md                      # Skill entry — triggers, capabilities, workflows
├── references/                   # Reference docs (8 deep-dive guides)
│   ├── pipeline-setup.md         #   Pipeline design from scratch
│   ├── troubleshooting.md        #   Structured error catalog (20+ entries)
│   ├── workflow-patterns.md      #   GitFlow / Trunk / GitOps / Canary patterns
│   ├── github-actions.md         #   GitHub Actions deep-dive
│   ├── docker.md                 #   Docker optimization best practices
│   ├── kubernetes.md             #   K8s deployment strategies
│   ├── jenkins.md                #   Jenkins pipelines & shared libraries
│   └── security.md               #   Supply chain security & secrets management
├── templates/                    # Reusable templates (29 total)
│   ├── github-actions/           #   8 CI/CD workflows
│   ├── docker/                   #   4 Dockerfiles + Compose + .dockerignore
│   ├── kubernetes/               #   7 K8s manifests
│   ├── jenkins/                  #   3 Jenkinsfiles
│   └── scripts/                  #   5 shell scripts
└── examples/                     # Complete example projects (2)
    ├── node-express-full/        #   Node.js Express end-to-end
    └── python-fastapi-full/      #   Python FastAPI end-to-end
```

## Template Catalog

### GitHub Actions (8)

| Template | Purpose |
|----------|---------|
| `node-ci.yml` | Node.js: lint → test (matrix) → build |
| `python-ci.yml` | Python: lint → mypy → test (matrix) |
| `go-ci.yml` | Go: lint → vet → test (race) → build (multi-arch) |
| `docker-build-push.yml` | Docker build+push + multi-arch + Trivy scan |
| `k8s-deploy.yml` | K8s deploy + rollout wait + health check + auto-rollback |
| `multi-env-deploy.yml` | Multi-env: dev → staging → prod (approval gates) |
| `release-please.yml` | Auto-release: Conventional Commits → version → changelog → release |
| `security-scan.yml` | Security: secret detection + dependency audit + CodeQL + container scan |

### Docker (6)

| Template | Purpose |
|----------|---------|
| `Dockerfile.node` | Node.js multi-stage (deps → build → runtime) |
| `Dockerfile.python` | Python multi-stage (wheels → runtime) |
| `Dockerfile.go` | Go static build (scratch image) |
| `Dockerfile.java-gradle` | Java/Gradle multi-stage |
| `docker-compose.ci.yml` | CI integration test orchestration (health-check-based wait) |
| `.dockerignore` | Comprehensive ignore rules (70+ patterns) |

### Kubernetes (7)

| Template | Purpose |
|----------|---------|
| `deployment.yaml` | Production-grade Deployment (probes / anti-affinity / security context) |
| `service.yaml` | Service configuration |
| `ingress.yaml` | Ingress + TLS + cert-manager |
| `configmap.yaml` | ConfigMap (key-value & file-based patterns) |
| `secret-sealed.yaml` | SealedSecret template (Bitnami Sealed Secrets) |
| `hpa.yaml` | HPA (CPU/memory + scale-up/scale-down policies) |
| `kustomization.yaml` | Kustomize base (with environment overlay instructions) |

### Shell Scripts (5)

| Template | Purpose |
|----------|---------|
| `health-check.sh` | HTTP health poller (configurable retries / interval / timeout / content assertion) |
| `deploy-rollback.sh` | Deployment rollback (supports K8s and Docker) |
| `env-validator.sh` | Pre-deployment environment validation (URL format / port range / secret leak detection) |
| `image-cleanup.sh` | Docker image garbage collection (age/count retention policy) |
| `pre-commit-ci-check.sh` | Pre-commit check (auto-detects project type, runs corresponding checks) |

### Jenkins (3)

| Template | Purpose |
|----------|---------|
| `Jenkinsfile-standard` | Standard declarative pipeline |
| `Jenkinsfile-docker` | Docker build+push + integration tests |
| `Jenkinsfile-k8s` | K8s deploy + auto-rollback |

## Usage Examples

### Scenario 1: Deployment Failure

```
User: My K8s Pod keeps CrashLoopBackOff

Claude:
1. Classify: K8s runtime error
2. Diagnostic steps:
   - kubectl logs <pod> --previous  # Check pre-crash logs
   - kubectl describe pod <pod>     # Check Events
   - kubectl top pod <pod>          # Check resource usage
3. Common causes: App startup crash / OOM / port conflict / bad config
4. Provide targeted fix

Reference: references/troubleshooting.md
```

### Scenario 2: CI/CD Setup from Scratch

```
User: Set up CI/CD for this Python project

Claude:
1. Detect: Python project, hosted on GitHub, deploys to K8s
2. Recommend: GitHub Actions (zero infra overhead)
3. Provide templates:
   - templates/github-actions/python-ci.yml  → .github/workflows/ci.yml
   - templates/docker/Dockerfile.python       → Dockerfile
   - templates/github-actions/k8s-deploy.yml  → .github/workflows/deploy.yml
4. Walk through {{PLACEHOLDER}} customization
5. Guide GitHub Secrets & Environments setup

Reference: references/pipeline-setup.md
```

### Scenario 3: Pipeline Optimization

```
User: My Docker build takes 12 minutes every time — how to speed it up?

Claude:
1. Analyze Dockerfile layer order: COPY . . before npm ci → every code change busts entire dependency cache
2. Optimization:
   - COPY package*.json first, THEN npm ci, THEN COPY . .
   - Enable BuildKit caching (GH Actions: cache-from: type=gha)
   - Add .dockerignore to exclude node_modules
3. Estimate: 12min → 2-3min (<30s on cache hit)

Reference: references/docker.md
```

## Security Principles (Non-Negotiable)

1. **Never hardcode secrets** — use CI Secret Manager / K8s Secrets / Vault
2. **Pin image digests in production** (`@sha256:...`), never mutable tags (`:latest`)
3. **Always run vulnerability scans in CI** — Trivy / Snyk / Docker Scout
4. **Principle of least privilege** — CI service accounts get only required permissions
5. **Never trust PR workflows** — `pull_request_target` must NEVER checkout external code

## Compatibility

| Tool | Minimum | Verified |
|------|---------|----------|
| Docker | 24.x | 27.x |
| Kubernetes | 1.26 | 1.30+ |
| GitHub Actions | — | 2024 Q4 |
| Jenkins | 2.400 | 2.440+ |
| Node.js | 18 LTS | 22 LTS |
| Python | 3.11 | 3.12 |
| Go | 1.21 | 1.22+ |

## Contributing

Issues and PRs welcome — more scenarios and templates appreciated.

## License

MIT License

---

<p align="center">
  <strong>Ready to use · Zero friction · Solves real problems</strong>
</p>
