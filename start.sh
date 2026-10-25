#!/usr/bin/env bash
# Container entrypoint: prep dirs, restore provider key from env (Space secrets),
# generate the Caddyfile (optional basic auth), skip Claude Code onboarding,
# start supervisord.
set -e

HOME_DIR="${HOME:-/home/agent}"
mkdir -p "$HOME_DIR/workspace" "$HOME_DIR/.claude" "$HOME_DIR/.cloudcli" "$HOME_DIR/.caddy" /tmp 2>/dev/null || true

# ---- restore provider config from env so it survives Space restarts ----------
# HF Space secrets/variables (Settings -> Variables and secrets):
#   CCW_KEY         (secret)    your provider API key
#   CCW_BASE_URL    (variable)  e.g. https://radoxai.com
#   CCW_PROVIDER    (variable)  optional, e.g. radoxai / custom
#   CCW_EXTRA_KEYS  (variable)  optional, comma-separated extra keys (rotation)
if [ -n "${CCW_KEY:-}" ]; then
  python3 - "${CCW_KEY}" "${CCW_BASE_URL:-}" "${CCW_PROVIDER:-custom}" "${CCW_EXTRA_KEYS:-}" <<'PY' || true
import json, os, sys
key, base, provider, extra = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
home = os.environ.get("HOME", "/home/agent")
cdir = os.path.join(home, ".claude")
os.makedirs(cdir, exist_ok=True)
settings_path = os.path.join(cdir, "settings.json")
state_path = os.path.join(cdir, "keymanager.json")

keys = [k.strip() for k in ([key] + extra.split(",")) if k.strip()]
if not base:
    base = {"radoxai": "https://radoxai.com", "openrouter": "https://openrouter.ai/api",
            "deepseek": "https://api.deepseek.com/anthropic", "moonshot": "https://api.moonshot.ai/anthropic",
            "zai": "https://api.z.ai/api/anthropic", "minimax": "https://api.minimax.io/anthropic",
            "anthropic": "https://api.anthropic.com"}.get(provider, "")

data = {}
if os.path.exists(settings_path):
    try:
        data = json.load(open(settings_path))
    except Exception:
        data = {}
env = data.setdefault("env", {})
env["ANTHROPIC_BASE_URL"] = base
env["ANTHROPIC_AUTH_TOKEN"] = keys[0]
env["ANTHROPIC_API_KEY"] = ""
env["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"] = "1"
with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
with open(state_path, "w") as f:
    json.dump({"provider": provider, "key": keys[0], "base_url": base, "keys": keys,
               "use_proxy": len(keys) > 1}, f, indent=2)
print("[start] provider key restored from env (CCW_KEY)")
PY
fi

# ---- generate the Caddyfile (single port, optional basic auth) ---------------
#   CCW_USER / CCW_PASS  (secrets) -> gate the whole app behind HTTP basic auth
python3 - "$HOME_DIR/.caddy" "${APP_PORT:-7860}" "${CCW_USER:-admin}" "${CCW_PASS:-}" <<'PY' || true
import os, subprocess, sys
caddy_dir, port, user, pw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
auth = ""
if pw:
    try:
        h = subprocess.run(["caddy", "hash-password", "--plaintext", pw],
                           capture_output=True, text=True, timeout=30).stdout.strip()
        if h:
            auth = "\tbasic_auth {\n\t\t%s %s\n\t}\n\n" % (user or "admin", h)
    except Exception:
        auth = ""
cfg = """{
	admin off
	auto_https off
}

:%s {
	encode zstd gzip

%shandle /admin* {
		reverse_proxy 127.0.0.1:8000
	}

	handle /gw* {
		reverse_proxy 127.0.0.1:8000
	}

	handle {
		reverse_proxy 127.0.0.1:3001 {
			flush_interval -1
		}
	}
}
""" % (port, auth)
os.makedirs(caddy_dir, exist_ok=True)
with open(os.path.join(caddy_dir, "Caddyfile"), "w") as f:
    f.write(cfg)
print("[start] Caddyfile written (basic_auth=%s)" % bool(pw))
PY

# Skip Claude Code's interactive first-run setup (only when no config exists yet)
if [ ! -f "$HOME_DIR/.claude.json" ]; then
  printf '{"hasCompletedOnboarding":true,"bypassPermissionsModeAccepted":true}\n' > "$HOME_DIR/.claude.json" 2>/dev/null || true
fi

echo "[start] claude   = $(command -v claude || echo 'NOT FOUND')"
echo "[start] cloudcli = $(command -v cloudcli || echo 'NOT FOUND')"
echo "[start] caddy    = $(command -v caddy || echo 'NOT FOUND')"
echo "[start] listening on port ${APP_PORT:-7860}"

exec supervisord -c /etc/supervisor/allinone.conf
