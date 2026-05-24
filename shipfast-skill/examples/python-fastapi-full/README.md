# Python FastAPI — Full CI/CD Example

This is a complete, production-ready CI/CD setup for a Python FastAPI application.

## What's Included

- `.github/workflows/ci.yml` — Full pipeline: lint (ruff), typecheck (mypy), test (pytest with PostgreSQL service container, matrix across Python 3.11/3.12), Docker build+push, Trivy scan, staging deploy (auto), production deploy (manual gate with health check + auto-rollback)
- `Dockerfile` — Multi-stage build (wheel builder → runtime), non-root user, health check
- `k8s/deployment.yaml` — Rolling update with pod anti-affinity, resource limits, liveness/readiness/startup probes, security context

## How to Use

1. Copy these files into your repository root
2. Update `IMAGE_NAME` in the CI workflow to your actual image name
3. Configure these GitHub Secrets:
   - `KUBE_CONFIG` (base64-encoded kubeconfig for staging)
   - `KUBE_CONFIG_PROD` (base64-encoded kubeconfig for production)
4. Set up GitHub Environments (Settings → Environments):
   - `staging` — optional
   - `production` — required reviewers + branch protection
5. Push to `main` to trigger the full pipeline

## Customization Points

- CI workflow: change `HEALTH_CHECK_URL` to your actual health endpoint
- K8s deployment: update `DATABASE_URL` and `SECRET_KEY` secret references
- Dockerfile: adjust `main:app` if your FastAPI app module name differs

## Security Notes

- Secrets sourced from GitHub Secrets, never committed
- Production deployment requires manual approval
- Docker image scanned with Trivy for HIGH/CRITICAL CVEs
- Container runs as non-root user with read-only root filesystem
- PostgreSQL service container in CI uses ephemeral storage
