#!/usr/bin/env bash
# Deploy Rollback Script — K8s + Docker rollback for CI/CD pipelines
# Usage:
#   K8s:  ./deploy-rollback.sh k8s <namespace> <deployment>
#   Docker: ./deploy-rollback.sh docker <service> <previous-tag>
set -euo pipefail

TYPE="${1:-}"
NAMESPACE_OR_SERVICE="${2:-}"
DEPLOYMENT_OR_TAG="${3:-}"

if [[ -z "$TYPE" || -z "$NAMESPACE_OR_SERVICE" ]]; then
  echo "Usage:"
  echo "  K8s:    $0 k8s <namespace> <deployment>"
  echo "  Docker: $0 docker <service> <previous-tag>"
  exit 1
fi

rollback_k8s() {
  local NAMESPACE="$1"
  local DEPLOYMENT="$2"

  echo "=== K8s Rollback: $DEPLOYMENT (namespace: $NAMESPACE) ==="

  # Show revision history
  echo "Revision history:"
  kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE"

  # Capture current pod logs for post-mortem
  echo "Capturing logs from current (failing) pods..."
  kubectl logs -l app="$DEPLOYMENT" -n "$NAMESPACE" --tail=100 --prefix=true > "/tmp/rollback-$DEPLOYMENT-$(date +%s).log" 2>/dev/null || true

  # Find the previous revision
  CURRENT_REVISION=$(kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE" | tail -1 | awk '{print $1}')
  if [[ -z "$CURRENT_REVISION" || "$CURRENT_REVISION" -le 1 ]]; then
    echo "ERROR: No previous revision to roll back to"
    exit 1
  fi

  PREVIOUS_REVISION=$((CURRENT_REVISION - 1))

  # Rollback
  echo "Rolling back from revision $CURRENT_REVISION to revision $PREVIOUS_REVISION..."
  kubectl rollout undo deployment/"$DEPLOYMENT" -n "$NAMESPACE" --to-revision="$PREVIOUS_REVISION"

  # Wait for rollout
  echo "Waiting for rollout to complete..."
  if ! kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=5m; then
    echo "ERROR: Rollback rollout did not complete within 5 minutes"
    exit 1
  fi

  # Verify new pods
  echo "Verifying pods after rollback..."
  kubectl get pods -n "$NAMESPACE" -l app="$DEPLOYMENT"

  echo "✓ Rollback complete"
}

rollback_docker() {
  local SERVICE="$1"
  local TAG="$2"

  if [[ -z "$TAG" ]]; then
    echo "ERROR: Previous tag is required for Docker rollback"
    exit 1
  fi

  echo "=== Docker Rollback: $SERVICE -> tag $TAG ==="

  # Pull the previous image
  echo "Pulling previous image..."
  docker pull "$SERVICE:$TAG"

  # Update the service
  echo "Updating service to $SERVICE:$TAG..."
  docker service update --image "$SERVICE:$TAG" "$SERVICE" 2>/dev/null || {
    # Fallback: docker-compose
    echo "Docker service update failed — trying docker-compose..."
    export IMAGE_TAG="$TAG"
    docker compose up -d --no-deps "$SERVICE"
  }

  # Health check
  echo "Waiting for service to stabilize..."
  sleep 10

  # Verify
  docker ps --filter "name=$SERVICE" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

  echo "✓ Rollback complete — $SERVICE now running $TAG"
}

case "$TYPE" in
  k8s)
    rollback_k8s "$NAMESPACE_OR_SERVICE" "$DEPLOYMENT_OR_TAG"
    ;;
  docker)
    rollback_docker "$NAMESPACE_OR_SERVICE" "$DEPLOYMENT_OR_TAG"
    ;;
  *)
    echo "ERROR: Unknown type '$TYPE'. Use 'k8s' or 'docker'."
    exit 1
    ;;
esac
