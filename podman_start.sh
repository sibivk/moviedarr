#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="moviedarr"
IMAGE_NAME="moviedarr:latest"
ENV_FILE=".env"

# ── Preflight checks ──────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.example to .env and fill in your credentials."
  exit 1
fi

# Check available disk space (warn if < 2GB free on the relevant filesystem)
AVAIL_KB=$(df --output=avail . | tail -1)
if [ "$AVAIL_KB" -lt 2097152 ]; then
  echo "WARNING: Less than 2 GB free on this filesystem. Consider cleaning up before building."
fi

# ── Parse key env vars from .env ─────────────────────────
_get_env() { grep -m1 "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'" | xargs; }

PORT=$(_get_env PORT);             PORT="${PORT:-5000}"
STORAGE_PATH=$(_get_env STORAGE_PATH); STORAGE_PATH="${STORAGE_PATH:-/tmp}"
NZBGET_URL=$(_get_env NZBGET_URL); NZBGET_URL="${NZBGET_URL:-}"

# ── Resolve NZBGet hostname for hairpin-NAT fix ───────────
# If NZBGET_URL resolves to this host's own IP, override DNS inside
# the container so it routes via host.containers.internal instead.
EXTRA_HOSTS=""
if [ -n "$NZBGET_URL" ]; then
  NZBGET_HOST=$(echo "$NZBGET_URL" | sed -E 's|https?://([^/:]+).*|\1|')
  HOST_IP=$(hostname -I | awk '{print $1}')
  RESOLVED=$(python3 -c "import socket; print(socket.gethostbyname('$NZBGET_HOST'))" 2>/dev/null || echo "")
  if [ "$RESOLVED" = "$HOST_IP" ]; then
    echo "Note: $NZBGET_HOST resolves to this host — overriding DNS in container via host.containers.internal"
    EXTRA_HOSTS="--add-host=${NZBGET_HOST}:169.254.1.2"
  fi
fi

# ── Build image ───────────────────────────────────────────
echo "Building ${IMAGE_NAME}..."
podman build -t "$IMAGE_NAME" -f Containerfile .

# ── Cleanup dangling moviedarr images ────────────────────
echo "Cleaning up dangling images..."
podman image prune -f --filter label=project=moviedarr 2>/dev/null || true
# Remove any old moviedarr tagged images (not :latest)
podman images --format "{{.ID}} {{.Repository}}:{{.Tag}}" \
  | awk '/moviedarr:/ && !/:latest/' \
  | awk '{print $1}' \
  | xargs -r podman rmi -f 2>/dev/null || true

# ── Create log directory ──────────────────────────────────
mkdir -p ./logs

# ── Stop & remove existing moviedarr container only ──────
if podman container exists "$CONTAINER_NAME"; then
  echo "Stopping existing $CONTAINER_NAME container..."
  podman stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
  podman rm   "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# ── Start container ───────────────────────────────────────
echo "Starting ${CONTAINER_NAME} on port ${PORT}..."
podman run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -p "${PORT}:5000" \
  -v "$(pwd)/logs:/app/logs:Z" \
  -v "${STORAGE_PATH}:/media:Z" \
  $EXTRA_HOSTS \
  "$IMAGE_NAME"

echo ""
echo "✓ ${CONTAINER_NAME} is running."
echo "  → http://localhost:${PORT}"
echo ""
podman ps -f name="$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
