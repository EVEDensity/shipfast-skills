# ShipFast

<p align="center">
  <strong>从提交到上线，快如闪电。</strong>
</p>

<p align="center">
  <a href="README.md">Home</a>
  ·
  <a href="#top">中文</a>
  ·
  <a href="README_EN.md">English</a>
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#为什么需要这个技能">痛点</a> ·
  <a href="#功能矩阵">功能矩阵</a> ·
  <a href="#五大核心工作流">核心工作流</a> ·
  <a href="#目录结构">目录结构</a> ·
  <a href="#模板清单">模板清单</a>
</p>

---

## 为什么需要这个技能？

日常开发中，你是否经常遇到：

- 部署失败，看半天日志找不到原因
- 新项目搭 CI/CD 要从零写 YAML，反复试错
- 流水线跑一次 20 分钟，不知道怎么优化
- 多环境部署靠手动改配置，经常搞混
- Docker 镜像 2GB，构建每次都要 10 分钟

**这个技能一次性解决上述所有问题。**

## 核心定位

聚焦日常研发高频痛点，提供**可直接复制使用**的脚本、配置文件和排查方案。覆盖 Git、Jenkins、Docker、Kubernetes、GitHub Actions 主流生态，满足个人开发、团队协作、项目上线全场景需求。

## 快速开始

### 1. 安装技能

将 `shipfast/` 目录放入你的 Claude Code skills 路径。

### 2. 触发使用

在 Claude Code 对话中直接描述问题或需求：

```
/ 我的 GitHub Actions 部署一直报 Permission denied
/ 帮我给这个 Node.js 项目搭建 CI/CD
/ Docker 镜像太大了，怎么优化？
/ 多环境（dev/staging/prod）部署怎么配？
/ K8s Pod 一直 CrashLoopBackOff 怎么排查？
```

技能会自动识别触发，并按照结构化工作流给出解决方案。

## 功能矩阵

| 工具 | 搭建 | 排错 | 优化 | 提供模板 |
|------|:---:|:---:|:---:|:-------:|
| **GitHub Actions** | ✓ | ✓ | ✓ | 8 个 YAML 工作流 |
| **Jenkins** | ✓ | ✓ | ✓ | 3 个 Jenkinsfile |
| **Docker** | ✓ | ✓ | ✓ | 4 个 Dockerfile + Compose + .dockerignore |
| **Kubernetes** | ✓ | ✓ | ✓ | 7 个 YAML 清单文件 |
| **Shell 脚本** | — | ✓ | ✓ | 5 个生产级脚本 |
| **安全扫描** | ✓ | ✓ | — | 密钥检测 + 镜像扫描 + SBOM |

## 五大核心工作流

### 1. 部署失败诊断

```
用户报告失败 → 识别工具和阶段 → 匹配错误模式 → 给出修复方案 + 验证命令
```

覆盖 GitHub Actions / Docker / K8s 共 20+ 种常见错误，每种提供 Symptom → Root Cause → Fix → Verify 完整链路。

### 2. 从零搭建 CI/CD

```
评估项目 → 推荐 CI 工具 → 选择模板 → 定制 {{PLACEHOLDER}} → 指导首次运行
```

支持 Node.js / Python / Go / Java 四大技术栈。

### 3. 流水线性能优化

```
分析配置 → 识别瓶颈（缓存/并行/Docker 层） → 提供 before/after diff → 优先应用高收益项
```

### 4. 多环境部署

```
映射环境 → 设计晋升流程 → 提供 multi-env-deploy.yml → 配置审批门禁和密钥隔离
```

### 5. 应用容器化

```
分析技术栈 → 生成 Dockerfile → 添加 CI 构建推送流程 → 接入 K8s 部署
```

## 目录结构

```
shipfast/
├── SKILL.md                      # 技能入口，触发规则与工作流定义
├── references/                   # 参考文档 (8 篇深度指南)
│   ├── pipeline-setup.md         #   流水线从零搭建
│   ├── troubleshooting.md        #   结构化错误目录（20+ 条目）
│   ├── workflow-patterns.md      #   GitFlow/Trunk/GitOps/Canary 模式
│   ├── github-actions.md         #   GitHub Actions 深度指南
│   ├── docker.md                 #   Docker 优化最佳实践
│   ├── kubernetes.md             #   K8s 部署策略与管理
│   ├── jenkins.md                #   Jenkins 流水线与共享库
│   └── security.md               #   供应链安全与密钥管理
├── templates/                    # 可复用模板 (29 个)
│   ├── github-actions/           #   8 个 CI/CD 工作流
│   ├── docker/                   #   4 个 Dockerfile + Compose + .dockerignore
│   ├── kubernetes/               #   7 个 K8s 清单文件
│   ├── jenkins/                  #   3 个 Jenkinsfile
│   └── scripts/                  #   5 个运维脚本
└── examples/                     # 完整示例项目 (2 个)
    ├── node-express-full/        #   Node.js Express 全链路
    └── python-fastapi-full/      #   Python FastAPI 全链路
```

## 模板清单

### GitHub Actions (8 个)

| 模板 | 用途 |
|------|------|
| `node-ci.yml` | Node.js 全流程：lint → test(矩阵) → build |
| `python-ci.yml` | Python 全流程：lint → mypy → test(矩阵) |
| `go-ci.yml` | Go 全流程：lint → vet → test(race) → build(多架构) |
| `docker-build-push.yml` | Docker 构建推送 + 多架构 + Trivy 扫描 |
| `k8s-deploy.yml` | K8s 部署 + rollout 等待 + 健康检查 + 自动回滚 |
| `multi-env-deploy.yml` | 多环境部署：dev → staging → prod（审批门禁）|
| `release-please.yml` | 自动发版：Conventional Commits → 版本号 → Changelog → Release |
| `security-scan.yml` | 安全扫描：密钥检测 + 依赖审计 + CodeQL + 容器扫描 |

### Docker (6 个)

| 模板 | 用途 |
|------|------|
| `Dockerfile.node` | Node.js 多阶段构建（deps→build→runtime）|
| `Dockerfile.python` | Python 多阶段构建（wheel→runtime）|
| `Dockerfile.go` | Go 静态构建（scratch 镜像）|
| `Dockerfile.java-gradle` | Java/Gradle 多阶段构建 |
| `docker-compose.ci.yml` | CI 集成测试编排（含健康检查依赖等待）|
| `.dockerignore` | 全面忽略规则（70+ 模式）|

### Kubernetes (7 个)

| 模板 | 用途 |
|------|------|
| `deployment.yaml` | 生产级 Deployment（探针/反亲和/安全上下文）|
| `service.yaml` | Service 配置 |
| `ingress.yaml` | Ingress + TLS + cert-manager |
| `configmap.yaml` | ConfigMap（键值 + 文件两种模式）|
| `secret-sealed.yaml` | SealedSecret 模板（Bitnami Sealed Secrets）|
| `hpa.yaml` | HPA（CPU/内存 + 扩缩容策略）|
| `kustomization.yaml` | Kustomize 基座（含环境 overlay 指引）|

### Shell 脚本 (5 个)

| 模板 | 用途 |
|------|------|
| `health-check.sh` | HTTP 健康检查（可配置重试/间隔/超时/内容断言）|
| `deploy-rollback.sh` | 部署回滚（支持 K8s 和 Docker）|
| `env-validator.sh` | 环境变量预检（URL格式/端口范围/密钥泄露检测）|
| `image-cleanup.sh` | Docker 镜像清理（按时间/数量保留策略）|
| `pre-commit-ci-check.sh` | 提交前检查（自动检测项目类型并运行对应检查）|

### Jenkins (3 个)

| 模板 | 用途 |
|------|------|
| `Jenkinsfile-standard` | 标准声明式流水线 |
| `Jenkinsfile-docker` | Docker 构建推送 + 集成测试 |
| `Jenkinsfile-k8s` | K8s 部署 + 自动回滚 |

## 使用示例

### 场景 1：部署报错速排

```
用户：我的 K8s Pod 一直 CrashLoopBackOff

Claude：
1. 分类：K8s 运行时错误
2. 诊断步骤：
   - kubectl logs <pod> --previous  # 查看崩溃前日志
   - kubectl describe pod <pod>     # 查看 Events
   - kubectl top pod <pod>          # 检查资源使用
3. 常见原因：应用启动崩溃 / OOM / 端口冲突 / 配置错误
4. 给出针对性修复

参考文件：references/troubleshooting.md
```

### 场景 2：从零搭建 CI/CD

```
用户：帮我给这个 Python 项目搭 CI/CD

Claude：
1. 检测：Python 项目，托管在 GitHub，部署到 K8s
2. 推荐：GitHub Actions（零基础设施开销）
3. 提供模板：
   - templates/github-actions/python-ci.yml  → .github/workflows/ci.yml
   - templates/docker/Dockerfile.python       → Dockerfile
   - templates/github-actions/k8s-deploy.yml  → .github/workflows/deploy.yml
4. 引导填写 {{PLACEHOLDER}} 占位符
5. 指导配置 GitHub Secrets 和 Environments

参考文件：references/pipeline-setup.md
```

### 场景 3：流水线优化

```
用户：我的 Docker 构建每次都 12 分钟，怎么优化？

Claude：
1. 分析 Dockerfile 层序：COPY . . 在 npm ci 之前 → 任何代码变更全部重装依赖
2. 优化方案：
   - 先 COPY package*.json，再 npm ci，最后 COPY . .
   - 启用 BuildKit 缓存（GH Actions: cache-from: type=gha）
   - 添加 .dockerignore 排除 node_modules
3. 预估：12min → 2-3min（缓存命中时 <30s）

参考文件：references/docker.md
```

## 安全原则（不可妥协）

1. **绝不硬编码密钥** — 所有凭据走 CI Secret Manager / K8s Secrets / Vault
2. **生产环境固定镜像摘要**（`@sha256:...`），而非可变标签（`:latest`）
3. **CI 流程必跑漏洞扫描** — Trivy / Snyk / Docker Scout
4. **最小权限原则** — CI 服务账号仅授予必要权限
5. **不信任 PR 工作流** — `pull_request_target` 绝不 checkout 外部代码

## 兼容性

| 工具 | 最低版本 | 验证版本 |
|------|---------|---------|
| Docker | 24.x | 27.x |
| Kubernetes | 1.26 | 1.30+ |
| GitHub Actions | — | 2024 Q4 |
| Jenkins | 2.400 | 2.440+ |
| Node.js | 18 LTS | 22 LTS |
| Python | 3.11 | 3.12 |
| Go | 1.21 | 1.22+ |

## 贡献

欢迎提 Issue 和 PR 补充更多场景和模板。

## 许可

MIT License

---

<p align="center">
  <strong>落地即用 · 零门槛 · 解决真问题</strong>
</p>
