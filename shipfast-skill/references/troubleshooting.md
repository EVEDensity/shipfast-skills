# CI/CD Troubleshooting — Error Catalog

Structured error catalog: **Symptom → Root Cause(s) → Fix → Verification**.

---

## GitHub Actions Errors

### Error: `Permission denied` on git push or PR comment

**Symptom**: `remote: Permission to repo.git denied to github-actions[bot]` or 403 on API calls.

**Root cause**: Default `GITHUB_TOKEN` has read-only scope for certain operations, or `permissions` block is too restrictive.

**Fix**: In workflow file, add explicit permissions:

```yaml
permissions:
  contents: write
  pull-requests: write
```

**Verify**: Re-run the workflow after updating permissions.

---

### Error: Secret not available in workflow

**Symptom**: `${{ secrets.MY_SECRET }}` resolves to empty string.

**Root causes**:
1. Secret is set at repo level but workflow runs from fork (PR from fork)
2. Secret name has a typo or incorrect casing
3. Secret is org-level but not synced to repo

**Fix**:
1. Use `pull_request_target` instead of `pull_request` for fork PRs (caution: security risk)
2. Verify secret name in Settings → Secrets and Variables → Actions
3. Check org secret policies for repository access

**Verify**: Add a debug step (temporarily): `echo "Secret length: ${{ secrets.MY_SECRET != '' }}"`

---

### Error: `No space left on device`

**Symptom**: Build fails with `ENOSPC` or disk full errors.

**Root cause**: GitHub Actions runners have 14GB disk; large Docker images, node_modules, or cached artifacts fill it up.

**Fix**:
```yaml
- name: Free disk space
  run: |
    sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc
    sudo docker system prune -af
```

**Verify**: Add `df -h` step before build to monitor.

---

### Error: Workflow not triggered on push

**Symptom**: Pushed code but workflow didn't start.

**Root causes**:
1. `on: push` path filter doesn't match changed files
2. Branch name pattern mismatch in `branches:` filter
3. Workflow file is in a non-default branch and not merged
4. Rate limited (public repos only)

**Fix**: Check `on:` block, ensure path filters use glob patterns (`**/*.js`, not `*.js`).

**Verify**: `gh run list -w <workflow-name>` or check Actions tab.

---

### Error: `Error: Resource not accessible by integration`

**Symptom**: 403 when using `actions/checkout` or other actions on private repos.

**Root cause**: `GITHUB_TOKEN` permissions insufficient, or trying to access a repo outside the current repository.

**Fix**: Set `permissions: contents: read` at minimum. For cross-repo access, use a PAT stored as a secret.

---

## Docker Errors

### Error: Build context too large

**Symptom**: `docker build` sends gigabytes of data, build hangs or times out.

**Root cause**: `.dockerignore` missing or incomplete; `node_modules`, `.git`, or build artifacts included in context.

**Fix**: Create/update `.dockerignore`:
```
node_modules
.git
*.log
dist
coverage
.cache
**/*.pyc
__pycache__
```

**Verify**: `docker build --no-cache . 2>&1 | head -5` — check context size line.

---

### Error: Layer cache always misses

**Symptom**: Docker builds in CI never hit cache despite repeated builds.

**Root cause**:
1. Docker layer order: files change before dependencies, causing full rebuild
2. `cache-from` / `cache-to` not configured
3. CI runner is ephemeral — no local cache persists

**Fix**: Restructure Dockerfile — COPY dependency files first, then run install, then COPY source:
```dockerfile
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

For GitHub Actions, use BuildKit cache:
```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

---

### Error: `exec format error`

**Symptom**: Container starts but exits immediately with `exec format error`.

**Root cause**: Architecture mismatch — built for `linux/amd64` but running on `linux/arm64` (or vice versa).

**Fix**: Build multi-arch images:
```yaml
- uses: docker/setup-qemu-action@v3
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
```

**Verify**: `docker manifest inspect <image>` — check listed platforms.

---

### Error: `no space left on device` in Docker

**Symptom**: `docker build` or `docker pull` fails with no space.

**Root cause**: Accumulated images, volumes, and build cache consuming CI runner disk.

**Fix**:
```bash
docker system prune -af --volumes
docker builder prune -af
```

**Verify**: `docker system df` — shows reclaimable space.

---

### Error: Registry authentication failure

**Symptom**: `unauthorized: authentication required` or `denied: requested access to the resource is denied`.

**Root causes**:
1. Registry credentials expired (token-based registries)
2. Wrong registry URL in login step
3. CI secret value is wrong or empty

**Fix**: Re-generate credentials, verify `docker/login-action` points to correct registry:
```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

---

## Kubernetes Errors

### Error: `ImagePullBackOff` / `ErrImagePull`

**Symptom**: Pod stuck in `ImagePullBackOff` or `ErrImagePull`.

**Root causes**:
1. Image tag doesn't exist or is misspelled
2. Registry requires authentication — `imagePullSecrets` missing
3. Private registry not accessible from cluster network
4. Image name includes wrong registry prefix

**Fix**:
```bash
# Check image exists locally
docker pull <image>

# Verify imagePullSecrets exists
kubectl get secrets -n <namespace>

# Create pull secret if missing
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<token> \
  -n <namespace>
```

**Verify**: `kubectl describe pod <pod> -n <namespace>` — check Events section.

---

### Error: `CrashLoopBackOff`

**Symptom**: Pod keeps restarting — status shows `CrashLoopBackOff`.

**Root causes**:
1. Application crashes on startup (bad config, missing env vars)
2. Wrong command or args in container spec
3. Port already in use within container
4. OOM without explicit memory limit (killed by kernel)

**Fix**:
```bash
# Check logs
kubectl logs <pod> -n <namespace> --previous

# Check resource usage
kubectl top pod <pod> -n <namespace>

# Get detailed events
kubectl describe pod <pod> -n <namespace>
```

**Verify**: Set appropriate resource limits, fix app config, re-deploy.

---

### Error: `OOMKilled`

**Symptom**: Pod terminated with reason `OOMKilled`, exit code 137.

**Root cause**: Container exceeded memory limit.

**Fix**:
```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"  # Increase this
```

**Verify**: `kubectl describe pod <pod>` — check State → Terminated → Reason.

---

### Error: `CreateContainerConfigError`

**Symptom**: Pod won't start, `CreateContainerConfigError` status.

**Root causes**:
1. ConfigMap or Secret referenced in volume doesn't exist
2. ConfigMap key referenced in `envFrom` doesn't exist
3. Invalid YAML in ConfigMap data

**Fix**:
```bash
kubectl get configmap <name> -n <namespace>
kubectl get secret <name> -n <namespace>
kubectl describe pod <pod> -n <namespace>  # Check Events
```

---

### Error: Pod stuck in `Pending`

**Symptom**: Pod never leaves Pending state.

**Root causes**:
1. Insufficient cluster resources (CPU/memory)
2. Node selector or affinity can't be satisfied
3. PersistentVolumeClaim can't bind
4. Taints on nodes not tolerated by pod

**Fix**:
```bash
kubectl describe pod <pod> -n <namespace>  # Check Events for scheduler messages
kubectl get nodes -o wide  # Check available nodes
kubectl describe node <node>  # Check capacity and taints
```

---

### Error: Service not routing to pods

**Symptom**: Service endpoint returns 503 or connection refused.

**Root cause**: Service selector doesn't match pod labels.

**Fix**:
```bash
# Check service selector
kubectl get svc <svc> -o jsonpath='{.spec.selector}'

# Check pod labels
kubectl get pods --show-labels

# Verify endpoints
kubectl get endpoints <svc>
```

Service selector must exactly match pod labels.

---

## Common Cross-Tool Errors

### SSL/TLS Certificate Expired

**Symptom**: `x509: certificate has expired or is not yet valid`.

**Root cause**: Server certificate expired, or system time out of sync.

**Fix**: Check `date` on the machine, contact service owner if certificate is expired.

---

### DNS Resolution Failure

**Symptom**: `Name or service not known`, `NXDOMAIN`.

**Root cause**: Wrong DNS config in container/cluster, or service name typo.

**Fix**: In K8s, verify service name: `<service>.<namespace>.svc.cluster.local`. In Docker, check `--dns` flag or `/etc/resolv.conf`.

---

### Network Timeout

**Symptom**: `Connection timed out`, `dial tcp ... i/o timeout`.

**Root causes**:
1. Security group / firewall blocking port
2. Service listening on `127.0.0.1` instead of `0.0.0.0`
3. NetworkPolicy in K8s blocks traffic

**Fix**: Verify the service binds to `0.0.0.0`, check firewall rules, check K8s NetworkPolicy:
```bash
kubectl get networkpolicies -n <namespace>
```

---

### Permission Denied on Volume Mount

**Symptom**: `PermissionError` on files in mounted volume.

**Root cause**: Container runs as non-root user but volume has root-owned files.

**Fix**:
```yaml
securityContext:
  runAsUser: 1000
  fsGroup: 1000
```

Or use `initContainer` to `chown` the volume before app starts.
