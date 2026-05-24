# Jenkins — Pipeline Patterns & Operational Knowledge

## Declarative vs Scripted Pipeline

### Declarative (Recommended)

```groovy
pipeline {
    agent any
    environment {
        APP_NAME = 'my-app'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
    }
    post {
        always {
            junit 'test-results/*.xml'
        }
        failure {
            slackSend(channel: '#ci-alerts', color: 'danger',
                      message: "Build failed: ${env.BUILD_URL}")
        }
    }
}
```

### When to Use Scripted

Only when you need:
- Complex conditional logic that can't be expressed declaratively
- Dynamic stage generation
- Very granular error handling

```groovy
node {
    stage('Checkout') {
        checkout scm
    }
    try {
        stage('Test') {
            sh 'npm test'
        }
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        stage('Cleanup') {
            cleanWs()
        }
    }
}
```

## Shared Libraries

### Directory Structure

```
jenkins-shared-library/
├── vars/                    # Global variables (callable from any pipeline)
│   ├── dockerBuild.groovy
│   ├── k8sDeploy.groovy
│   └── notifySlack.groovy
├── src/                     # Java/Groovy classes
│   └── org/myorg/
│       └── Utils.groovy
└── resources/               # Static files
    └── templates/
        └── deployment.yaml
```

### Example Shared Library Function

```groovy
// vars/dockerBuild.groovy
def call(Map config = [:]) {
    def imageName = config.imageName ?: error('imageName is required')
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def registry = config.registry ?: 'ghcr.io'

    sh """
        docker build \
            -t ${registry}/${imageName}:${env.BUILD_NUMBER} \
            -t ${registry}/${imageName}:latest \
            -f ${dockerfile} .
        docker push ${registry}/${imageName}:${env.BUILD_NUMBER}
        docker push ${registry}/${imageName}:latest
    """
    return "${registry}/${imageName}:${env.BUILD_NUMBER}"
}
```

### Usage in Jenkinsfile

```groovy
@Library('shared-library@v1.2.0') _

pipeline {
    agent any
    stages {
        stage('Docker Build') {
            steps {
                script {
                    def image = dockerBuild(
                        imageName: 'my-org/my-app',
                        dockerfile: 'Dockerfile.prod'
                    )
                    env.IMAGE = image
                }
            }
        }
    }
}
```

### Library Versioning

Reference specific versions, never `main` branch:

```groovy
@Library('shared-library@v1.2.0') _    // Tag
@Library('shared-library@abc1234') _    // Commit SHA
// NEVER: @Library('shared-library@main') _   // Mutable!
```

## Multibranch Pipeline

Automatically discovers branches and creates pipelines.

```groovy
// Jenkinsfile at repo root
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
    }
    post {
        success {
            script {
                if (env.BRANCH_NAME == 'main') {
                    build job: 'deploy-to-production', wait: false
                }
            }
        }
    }
}
```

Configure in Jenkins: New Item → Multibranch Pipeline → Add Git source.

## Agent/Node Selection

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: node
    image: node:20-alpine
    command: ['sleep']
    args: ['infinity']
  - name: docker
    image: docker:27-dind
    securityContext:
      privileged: true
'''
        }
    }
    stages { ... }
}
```

### Label-Based Selection

```groovy
stage('Build ARM') {
    agent { label 'linux-arm64' }  // Only run on ARM nodes
    steps { ... }
}

stage('Build AMD64') {
    agent { label 'linux-amd64' }
    steps { ... }
}
```

## Credential Binding

```groovy
pipeline {
    agent any
    environment {
        // Bind username/password to env vars
        DOCKER_CREDS = credentials('docker-registry')
    }
    stages {
        stage('Docker Login') {
            steps {
                sh '''
                    docker login -u $DOCKER_CREDS_USR -p $DOCKER_CREDS_PSW ghcr.io
                '''
            }
        }
        stage('Use SSH Key') {
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: 'deploy-key',
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh 'ssh -i $SSH_KEY user@server "deploy.sh"'
                }
            }
        }
    }
}
```

## Build Performance Optimization

### Parallel Stages

```groovy
stage('Test') {
    parallel {
        stage('Unit Tests') {
            steps { sh 'npm run test:unit' }
        }
        stage('Integration Tests') {
            steps { sh 'npm run test:integration' }
        }
        stage('Lint') {
            steps { sh 'npm run lint' }
        }
    }
}
```

### Workspace Cleanup

```groovy
post {
    always {
        cleanWs(
            cleanWhenNotBuilt: false,
            deleteDirs: true,
            disableDeferredWipeout: true
        )
    }
}
```

### Artifact Retention

```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '30', daysToKeepStr: '7'))
}
```

## Jenkins → GitHub Actions Migration

| Jenkins | GitHub Actions |
|---------|---------------|
| `pipeline { agent any }` | `jobs: <job>: runs-on: ubuntu-latest` |
| `environment { FOO = 'bar' }` | `env:` at job or step level |
| `stage('Test') { steps { sh 'npm test' } }` | `- name: Test` `  run: npm test` |
| `when { branch 'main' }` | `if: github.ref == 'refs/heads/main'` |
| `parameters { string(name: 'ENV') }` | `workflow_dispatch: inputs:` |
| `credentials('docker-creds')` | `${{ secrets.DOCKER_CREDS }}` |
| `stash name: 'build'` | `actions/upload-artifact` |
| `unstash 'build'` | `actions/download-artifact` |
| `parallel { ... }` | `strategy: matrix:` or parallel jobs |
| `post { always { ... } }` | `if: always()` on a step |
| `timeout(time: 15, unit: 'MINUTES')` | `timeout-minutes: 15` |
| `build job: 'downstream'` | `workflow_dispatch` via `gh workflow run` |

## Common Jenkins Errors

| Error | Fix |
|-------|-----|
| Executor starvation (jobs queueing) | Add more executors or agents; check `Jenkins → Manage → Nodes` |
| Plugin conflict after update | Pin plugin versions; test in staging Jenkins first |
| Workspace corruption (leftover files) | Add `cleanWs()` in `post { always {} }` |
| Credential not found | Verify credential ID in `Jenkins → Credentials` |
| `No such DSL method` | Check shared library version; check method signature |
| Pipeline hangs in input step | Use `input` with timeout: `input(message: 'Proceed?', submitter: 'admin', timeout: time: 1, unit: 'HOURS')` |
| Disk full on master | Clean old builds: `Jenkins → Manage → Script Console`: `Jenkins.instance.items.each { it.builds.logRotate(30, 7, -1, -1) }` |
