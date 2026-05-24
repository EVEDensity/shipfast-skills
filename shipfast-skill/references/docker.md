# Docker — CI/CD Optimization & Best Practices

## Multi-Stage Build Patterns

### Node.js

```dockerfile
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS runtime
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

### Python

```dockerfile
# Stage 1: Build wheels
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime
RUN groupadd -r app && useradd -r -g app app
WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache /wheels/*.whl && rm -rf /wheels
COPY . .
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0"]
```

### Go

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X main.version=$VERSION" -o /app/server .

# Stage 2: Runtime
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/server /server
EXPOSE 8080
USER 1000:1000
CMD ["/server"]
```

### Java (Gradle)

```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY gradlew build.gradle settings.gradle ./
COPY gradle gradle
RUN ./gradlew --no-daemon dependencies
COPY src src
RUN ./gradlew --no-daemon bootJar

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health | grep -q UP
CMD ["java", "-XX:+UseZGC", "-jar", "app.jar"]
```

## Layer Caching Optimization

**Rule**: Order layers from least-frequently-changed to most-frequently-changed.

```dockerfile
# BAD — any source change busts npm cache
COPY . .
RUN npm ci

# GOOD — package.json changes rarely, source changes often
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

**Common dependency files to copy first**:

| Language | Install Layer |
|----------|---------------|
| Node.js | `package.json` + `package-lock.json` |
| Python | `requirements.txt` or `pyproject.toml` |
| Go | `go.mod` + `go.sum` |
| Java/Gradle | `build.gradle` + `settings.gradle` + `gradlew` + `gradle/` |
| Rust | `Cargo.toml` + `Cargo.lock` |

## Image Tagging Strategies

```bash
# In CI pipeline
IMAGE="ghcr.io/${{ github.repository }}"

# Tags: git SHA (for traceability) + semver (for humans)
docker tag app "$IMAGE:${{ github.sha }}"
docker tag app "$IMAGE:${{ steps.version.outputs.version }}"
docker tag app "$IMAGE:latest"  # Only for dev/staging, never for production

docker push "$IMAGE:${{ github.sha }}"
docker push "$IMAGE:${{ steps.version.outputs.version }}"
```

**Tagging rules**:
- `:latest` — mutable, for development only
- `:v1.2.3` — semver, for staging and release references
- `:sha-abcdef1` — immutable, for production (use digest instead: `@sha256:...`)

## Image Scanning in CI

### Trivy (free, fast)

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.build.outputs.image }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'HIGH,CRITICAL'
    exit-code: 0  # Non-blocking — upload results for review

- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

### Docker Scout

```yaml
- uses: docker/scout-action@v1
  with:
    command: cves
    image: ${{ steps.build.outputs.image }}
    only-severities: critical,high
```

## Docker Compose for CI Integration Tests

```yaml
# docker-compose.ci.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/testdb
      NODE_ENV: test
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 5s
      timeout: 3s
      retries: 10

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: testdb
    tmpfs: /var/lib/postgresql/data  # Ephemeral — no persistence
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d testdb"]
      interval: 3s
      timeout: 3s
      retries: 5
```

```yaml
# In GitHub Actions
- name: Run integration tests
  run: |
    docker compose -f docker-compose.ci.yml up -d
    docker compose -f docker-compose.ci.yml exec -T app npm run test:integration
    docker compose -f docker-compose.ci.yml down -v
```

## BuildKit Features

### Secrets (don't bake into image)

```dockerfile
# Dockerfile
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t my-app .
```

### Cache Mounts

```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
```

In CI, use `cache-from` + `cache-to` with GitHub Actions cache backend instead (persists across runs).

### SSH Mounts

```dockerfile
RUN --mount=type=ssh git clone git@github.com:org/private-repo.git
```

Never use in CI — use token-based auth instead.

## Image Size Reduction

| Technique | Typical Savings |
|-----------|----------------|
| Multi-stage build | 40-70% smaller |
| Use `-slim` or `-alpine` base image | 50-80% vs full image |
| Remove package cache (`apt clean`, `apk cache clean`) | 50-200MB |
| Combine RUN commands (fewer layers) | 10-15% |
| Use `.dockerignore` aggressively | Context size, not image size |
| Use `--no-install-recommends` (apt) | 30-100MB |
| Static binary to `scratch` or `distroless` | 95%+ reduction |

## `.dockerignore` Template

```
# Dependencies
node_modules
.pnpm-store
vendor

# Build artifacts
dist
build
target
*.class

# Version control
.git
.gitignore
.gitattributes

# CI/CD
.github
.gitlab-ci.yml
Jenkinsfile

# Environment
.env
.env.*
*.local

# Logs & temp
*.log
*.tmp
.cache
coverage
.nyc_output

# IDE
.vscode
.idea
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Documentation
README.md
CHANGELOG.md
docs
```
