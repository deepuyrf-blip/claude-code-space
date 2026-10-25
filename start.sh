#!/usr/bin/env bash
# Container entrypoint: prep dirs, skip Claude Code onboarding, start supervisord.
set -e

HOME_DIR="${HOME:-/home/agent}"
mkdir -p "$HOME_DIR/workspace" "$HOME_DIR/.claude" "$HOME_DIR/.cloudcli" /tmp 2>/dev/null || true

# Skip Claude Code's interactive first-run setup (only when no config exists yet)
if [ ! -f "$HOME_DIR/.claude.json" ]; then
  printf '{"hasCompletedOnboarding":true,"bypassPermissionsModeAccepted":true}\n' > "$HOME_DIR/.claude.json" 2>/dev/null || true
fi

echo "[start] claude   = $(command -v claude || echo 'NOT FOUND')"
echo "[start] cloudcli = $(command -v cloudcli || echo 'NOT FOUND')"
echo "[start] caddy    = $(command -v caddy || echo 'NOT FOUND')"
echo "[start] listening on port ${APP_PORT:-7860}"

exec supervisord -c /etc/supervisor/allinone.conf
