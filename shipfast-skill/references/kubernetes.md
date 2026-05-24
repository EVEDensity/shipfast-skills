# Kubernetes — Deployment Strategies & Manifest Management

## Deployment Strategies

### RollingUpdate (default, zero-downtime)

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1         # Max extra pods during update
      maxUnavailable: 0   # Never drop below desired count
```

**Best for**: Stateless apps, standard deployments.

### Recreate (downtime, simple)

```yaml
spec:
  strategy:
    type: Recreate
```

**Best for**: Stateful apps that can't have multiple instances, database migrations.

### Blue-Green (Kustomize/Helm or service switch)

Pattern: Deploy new version (`green`) alongside old (`blue`), then switch service selector.

```bash
# Deploy green
kubectl apply -f deployment-green.yaml

# Verify green is healthy
kubectl rollout status deployment/my-app-green

# Switch to green
kubectl patch service my-app -p '{"spec":{"selector":{"version":"green"}}}'

# Keep blue for rollback — delete after confirming
```

### Canary (Argo Rollouts)

See `references/workflow-patterns.md` for full canary setup.

## Manifest Templating: Kustomize vs Helm

| Criteria | Kustomize | Helm |
|----------|-----------|------|
| **Learning curve** | Low | Medium-high |
| **Template syntax** | None (pure YAML overlay) | Go templates |
| **Built into kubectl** | Yes (`kubectl apply -k`) | No (requires `helm` CLI) |
| **Package distribution** | Git repo | Helm repo / OCI |
| **Best for** | GitOps, environment variants | Reusable apps, public charts |
| **Secret management** | Separate tools (SOPS, SealedSecrets) | `helm secrets` plugin |

**Decision rule**:
- Internal app with few env variants → Kustomize
- Third-party app or distributing to others → Helm
- GitOps with ArgoCD → Kustomize

### Kustomize Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml   # patches + images
    │   └── replica-patch.yaml
    └── production/
        ├── kustomization.yaml
        ├── replica-patch.yaml
        └── resource-patch.yaml
```

**Base kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
images:
  - name: my-app
    newTag: latest  # Overridden by overlays
commonLabels:
  app: my-app
```

**Overlay kustomization.yaml** (staging):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: replica-patch.yaml
images:
  - name: my-app
    newTag: sha-abc123
namespace: staging
```

## Secret Management

### Option 1: Sealed Secrets (encrypted in git)

```bash
# Install controller in cluster
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/controller.yaml

# Encrypt a secret
kubectl create secret generic db-creds \
  --from-literal=password=s3cret \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml

# The sealed-secret.yaml can safely be committed to git
```

### Option 2: External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-creds
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-creds
  data:
    - secretKey: password
      remoteRef:
        key: prod/db/password
```

### Option 3: SOPS + Age

```bash
# Encrypt
sops --encrypt --age <public-key> secret.yaml > secret.enc.yaml

# Decrypt in CI
sops --decrypt secret.enc.yaml | kubectl apply -f -
```

## Health Check Configuration

### Probes Cheat Sheet

```yaml
livenessProbe:    # "Is the app alive?" — restart if fails
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15   # Wait for app to start
  periodSeconds: 20         # Check every 20s
  timeoutSeconds: 5
  failureThreshold: 3       # Restart after 3 failures

readinessProbe:   # "Can the app serve traffic?" — remove from service if fails
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 2

startupProbe:     # "Has the app finished starting?" — blocks liveness/readiness
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 5
  failureThreshold: 30      # Up to 150s for slow startup
```

**Rules**:
- Use `startupProbe` for apps with slow initialization (>30s)
- Liveness probe must NOT check external dependencies (DB, API) — only internal state
- Readiness probe CAN check dependencies — and should if the app can't serve without them
- Never set `failureThreshold: 0` — that disables the probe

## Resource Limits & HPA

### Resource Configuration

```yaml
resources:
  requests:    # What the pod is guaranteed
    memory: "256Mi"
    cpu: "250m"
  limits:      # Hard ceiling
    memory: "512Mi"
    cpu: "500m"
```

**Rules**:
- Always set requests = limits in production (Guaranteed QoS)
- Never set CPU limits (let it burst) if you understand the risks
- Set memory request = limit to avoid OOM eviction lottery

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up immediately
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
```

## CI/CD Integration Patterns

### GitHub Actions → kubectl deploy

```yaml
- name: Deploy to K8s
  uses: azure/k8s-set-context@v3
  with:
    kubeconfig: ${{ secrets.KUBE_CONFIG }}

- run: |
    kustomize build k8s/overlays/${{ inputs.environment }} | \
    kubectl apply -f -
    kubectl rollout status deployment/my-app -n ${{ inputs.environment }} --timeout=5m
```

### GitHub Actions → Helm deploy

```yaml
- name: Deploy with Helm
  uses: azure/setup-helm@v4

- run: |
    helm upgrade --install my-app ./chart \
      --namespace ${{ inputs.environment }} \
      --set image.tag=${{ github.sha }} \
      --set env=${{ inputs.environment }} \
      --wait --timeout 5m
```

## Rollback Strategies

### Instant Rollback (kubectl)

```bash
# Undo last deployment
kubectl rollout undo deployment/my-app -n production

# Undo to specific revision
kubectl rollout undo deployment/my-app -n production --to-revision=3

# Check revision history
kubectl rollout history deployment/my-app -n production
```

### Check Revisions Before Rollback

```bash
kubectl rollout history deployment/my-app -n production
# REVISION  CHANGE-CAUSE
# 3        <image: my-app@sha256:abc>
# 4        <image: my-app@sha256:def>  ← current (bad)
# Rollback to revision 3
kubectl rollout undo deployment/my-app -n production --to-revision=3
```

### Rollback Verification

```bash
kubectl rollout status deployment/my-app -n production --timeout=2m
kubectl get pods -n production -l app=my-app
```

## Common K8s Deployment Errors

See `references/troubleshooting.md` for the full catalog. Quick reference:

| Error | First Command |
|-------|---------------|
| ImagePullBackOff | `kubectl describe pod <pod>` — check image name and pull secrets |
| CrashLoopBackOff | `kubectl logs <pod> --previous` |
| OOMKilled | `kubectl top pod <pod>` — increase memory limit |
| CreateContainerConfigError | Check ConfigMap/Secret exists and keys match |
| Pending | `kubectl describe pod <pod>` — check Events for scheduler messages |
| 503 from Service | `kubectl get endpoints <svc>` — verify selector matches pod labels |
