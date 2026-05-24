# GitHub Actions — Patterns, Pitfalls & Advanced Usage

## Workflow Syntax Reference

### Trigger Events

```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'package.json'
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]
  schedule:
    - cron: '0 9 * * 1'  # Every Monday 9am UTC
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [staging, production]
  release:
    types: [published]
```

### Concurrency — Cancel Redundant Runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

For PRs: `${{ github.workflow }}-${{ github.head_ref || github.run_id }}`
For deployments: don't cancel — use unique group per environment.

### Job-Level Defaults

```yaml
defaults:
  run:
    shell: bash
    working-directory: ./src

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    strategy:
      matrix:
        node-version: [18, 20, 22]
      fail-fast: false  # Don't cancel other versions if one fails
    steps: ...
```

## Secret and Environment Variable Management

### Setting Secrets

```bash
gh secret set MY_SECRET --body "value" --repo owner/repo
gh secret set MY_SECRET --body "value" --org my-org     # Org-level
```

### Using Secrets

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}

steps:
  - run: |
      echo "Using secret: ${{ secrets.API_KEY }}"
      # DON'T do: echo "${{ secrets.API_KEY }}"  # This exposes in logs!
```

### Environment-Specific Secrets (GitHub Environments)

```yaml
jobs:
  deploy-staging:
    environment: staging
    # Uses secrets from Settings → Environments → staging
    steps: ...

  deploy-prod:
    environment: production
    # Uses secrets from Settings → Environments → production
    steps: ...
```

Environment protection rules:
- Required reviewers (up to 6)
- Wait timer (minutes)
- Branch restriction (only from main)
- Deployment history retained

## Caching Strategies

### Node.js (npm)

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'  # Auto-caches ~/.npm

- run: npm ci  # Uses cache
```

### Python (pip)

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'

- run: pip install -r requirements.txt
```

### Go Modules

```yaml
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    cache: true

- run: go mod download
```

### Custom Cache (any path)

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/my-tool
      node_modules/.cache
    key: ${{ runner.os }}-my-tool-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-my-tool-
```

### Docker Layer Cache (BuildKit)

```yaml
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    context: .
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## Matrix Builds

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node-version: [18, 20, 22]
    exclude:
      - os: windows-latest
        node-version: 18  # Skip this combination
    include:
      - os: macos-latest
        node-version: 22  # Add this combination

runs-on: ${{ matrix.os }}
steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
```

## Composite Actions (Reusable Steps)

```yaml
# .github/actions/setup-app/action.yml
name: 'Setup Application'
description: 'Install deps and build'
inputs:
  node-version:
    description: 'Node version'
    required: true
    default: '20'
runs:
  using: 'composite'
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: 'npm'
    - run: npm ci
      shell: bash
    - run: npm run build
      shell: bash
```

Usage in workflow:
```yaml
- uses: ./.github/actions/setup-app
  with:
    node-version: '22'
```

## Reusable Workflows (Callable)

```yaml
# .github/workflows/_deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      KUBE_CONFIG:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - run: kubectl apply -f k8s/
```

Usage:
```yaml
jobs:
  call-deploy:
    uses: ./.github/workflows/_deploy.yml
    with:
      environment: staging
    secrets:
      KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
```

## Self-Hosted Runners

### Adding a Runner

```bash
# In repo → Settings → Actions → Runners → New self-hosted runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64.tar.gz -L <url>
tar xzf ./actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/<owner>/<repo> --token <token>
./run.sh
```

### Security for Self-Hosted Runners

WARNING: Never use self-hosted runners on public repos. PR authors can run arbitrary code on your infrastructure.

For private repos:
- Use ephemeral runners (`--ephemeral` flag)
- Isolate runners in VMs/containers, not bare metal
- Rotate runner tokens regularly
- Limit runner access via `runs-on` labels

### Label Strategy

```bash
./config.sh --labels linux,gpu,pci-dss  # Tag with capabilities + compliance
```

```yaml
runs-on: [self-hosted, linux, gpu]  # Only runners with ALL labels match
```

## Common Pitfalls

1. **`GITHUB_TOKEN` has limited scope** — can't trigger other workflows (to prevent recursion). Use a PAT if you need workflow chaining.

2. **Artifact retention** — default 90 days (public repos) / 400 days (private). Delete old artifacts or set shorter retention.

3. **Workflow dispatch inputs are strings** — cast explicitly in expressions: `${{ fromJSON(inputs.debug) }}`

4. **Expression syntax in `if:`** — don't use `${{ }}` inside `if:` conditions:
   ```yaml
   if: github.ref == 'refs/heads/main'  # CORRECT
   if: ${{ github.ref == 'refs/heads/main' }}  # WRONG
   ```

5. **Rate limiting** — GitHub Actions has 1000 API requests/hour/repo. Use `actions/checkout` fetch-depth:1 for large repos.

## Migration: Jenkins to GitHub Actions

| Jenkins Concept | GitHub Actions Equivalent |
|----------------|--------------------------|
| Pipeline (Jenkinsfile) | Workflow (.github/workflows/*.yml) |
| Stage | Job |
| Node/Agent | `runs-on` |
| `when` condition | `if:` |
| `parameters` | `workflow_dispatch inputs` |
| `credentials()` | `secrets.XXX` |
| `stash`/`unstash` | `actions/upload-artifact` / `actions/download-artifact` |
| `parallel` | `strategy.matrix` or parallel jobs |
| Shared Library | Reusable workflow or composite action |
| `post { always { } }` | `if: always()` step |
| `timeout` | `timeout-minutes` |
| Blue Ocean | Actions tab UI |
