# Node.js Express — Full CI/CD Example

This is a complete, production-ready CI/CD setup for a Node.js Express API.

## What's Included

- `.github/workflows/ci.yml` — Full pipeline: lint, test (matrix across Node 18/20/22), Docker build+push (multi-arch), Trivy scan, staging deploy (auto), production deploy (manual gate with health check + auto-rollback)
- `Dockerfile` — Multi-stage build (deps → build → runtime), non-root user, health check
- `k8s/deployment.yaml` — Rolling update with pod anti-affinity, resource limits, liveness/readiness/startup probes, security context

## How to Use

1. Copy these files into your repository root
2. Update `IMAGE_NAME` in the CI workflow to your actual image name
3. Configure these GitHub Secrets:
   - `KUBE_CONFIG` (base64-encoded kubeconfig for staging)
   - `KUBE_CONFIG_PROD` (base64-encoded kubeconfig for production)
4. Set up GitHub Environments (Settings → Environments):
   - `staging` — optional protection rules
   - `production` — required reviewers + branch protection
5. Push to `main` to trigger the full pipeline

## Customization Points

- CI workflow: change `HEALTH_CHECK_URL` to your actual health endpoint
- K8s deployment: update resource limits based on your app's actual usage
- Dockerfile: adjust `dist/index.js` if your build output differs

## Security Notes

- Secrets are NEVER in these files — they come from GitHub Secrets
- Production deployment requires manual approval via GitHub Environments
- Docker image is scanned with Trivy for HIGH/CRITICAL CVEs before push
- Container runs as non-root user (UID 1000) with read-only root filesystem
