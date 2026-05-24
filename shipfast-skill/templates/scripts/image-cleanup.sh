#!/usr/bin/env bash
# Docker Image Cleanup — Garbage collection for CI runners and dev machines
# Usage: ./image-cleanup.sh [--older-than N] [--keep N] [--dry-run]
set -euo pipefail

OLDER_THAN_DAYS=7
KEEP_RECENT=5
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --older-than) OLDER_THAN_DAYS="$2"; shift 2 ;;
    --keep) KEEP_RECENT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Docker Image Cleanup ==="
echo "Remove images older than: ${OLDER_THAN_DAYS} days"
echo "Keep at least:           ${KEEP_RECENT} recent images"
echo "Dry run:                 $DRY_RUN"
echo "============================"

# Show current disk usage
echo ""
echo "Current disk usage:"
docker system df

RECLAIMED=0

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] $*"
  else
    "$@"
  fi
}

# 1. Remove dangling images (untagged, <none>:<none>)
DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
echo ""
echo "--- Dangling images: $DANGLING ---"
if [[ "$DANGLING" -gt 0 ]]; then
  run_cmd docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
  echo "Removed $DANGLING dangling images"
else
  echo "Nothing to remove"
fi

# 2. Remove images older than N days (excluding those still in use by containers)
echo ""
echo "--- Images older than ${OLDER_THAN_DAYS} days ---"
OLD_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | \
  while read -r line; do
    image=$(echo "$line" | awk '{print $1}')
    created=$(echo "$line" | awk '{print $2, $3}')
    created_epoch=$(date -d "$created" +%s 2>/dev/null || echo 0)
    cutoff_epoch=$(date -d "$OLDER_THAN_DAYS days ago" +%s)
    if [[ "$created_epoch" -lt "$cutoff_epoch" ]]; then
      echo "$image"
    fi
  done)

OLD_COUNT=$(echo "$OLD_IMAGES" | grep -c . || echo 0)
if [[ "$OLD_COUNT" -gt "$KEEP_RECENT" ]]; then
  TO_DELETE=$(echo "$OLD_IMAGES" | head -n -"$KEEP_RECENT")
  DELETE_COUNT=$(echo "$TO_DELETE" | grep -c . || echo 0)
  echo "Would remove $DELETE_COUNT images (keeping $KEEP_RECENT most recent)"
  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    # Skip images currently used by running containers
    if docker ps --format '{{.Image}}' | grep -qF "$image"; then
      echo "  SKIP $image (in use by container)"
      continue
    fi
    run_cmd docker rmi "$image" 2>/dev/null || echo "  FAIL $image (may be in use)"
  done <<< "$TO_DELETE"
else
  echo "Only $OLD_COUNT old images (threshold: $KEEP_RECENT) — nothing to remove"
fi

# 3. Prune build cache
echo ""
echo "--- Build cache ---"
run_cmd docker builder prune -f 2>/dev/null || true

# 4. Prune unused volumes (safely)
echo ""
echo "--- Unused volumes ---"
run_cmd docker volume prune -f 2>/dev/null || true

# Show result
echo ""
echo "=== After Cleanup ==="
docker system df

echo ""
echo "✓ Cleanup complete"
