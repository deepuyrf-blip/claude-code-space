# All-in-one Claude Code web UI for a single container (Hugging Face Spaces,
# Railway, Render, Fly.io, or any VPS). Runs CloudCLI + the /admin key manager
# + a Caddy reverse proxy on ONE port (default 7860).
#
# Based on Docker's Claude Code sandbox template (Ubuntu, non-root `agent` uid 1000).
FROM docker/sandbox-templates:claude-code

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git jq ripgrep sqlite3 zip unzip tree less supervisor \
    && rm -rf /var/lib/apt/lists/*

# Caddy (single static binary) - the single-port reverse proxy
RUN curl -fsSL "https://caddyserver.com/api/download" -o /usr/local/bin/caddy \
    && chmod +x /usr/local/bin/caddy && caddy version

# CloudCLI web UI + typescript (plugin builds need tsc)
USER agent
RUN npm install -g @cloudcli-ai/cloudcli typescript \
        --fetch-retries=5 --fetch-timeout=600000 --no-audit --no-fund \
    && cloudcli --version && tsc --version

# Graphify skill CLI (best effort)
RUN python3 -m pip install --user --break-system-packages graphifyy 2>/dev/null \
    || python3 -m pip install --user graphifyy 2>/dev/null \
    || echo "graphify skipped"

# ---- other agent CLIs (Codex / OpenCode / Cursor) - each needs its own login ----
RUN npm install -g @openai/codex opencode-ai \
        --fetch-retries=5 --fetch-timeout=600000 --no-audit --no-fund \
    && { command -v codex >/dev/null 2>&1 && echo "codex ok" || echo "codex missing"; } \
    && { command -v opencode >/dev/null 2>&1 && echo "opencode ok" || echo "opencode missing"; }
RUN curl -fsSL https://cursor.com/install | bash || echo "cursor-agent skipped"
ENV PATH=/home/agent/.local/bin:${PATH}

# app files
USER root
COPY app.py /opt/keymgr/app.py
COPY Caddyfile /etc/caddy/Caddyfile
COPY supervisord.conf /etc/supervisor/allinone.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh \
    && mkdir -p /home/agent/workspace /home/agent/.claude /home/agent/.cloudcli /opt/keymgr \
    && chown -R agent:agent /home/agent /opt/keymgr

ENV HOST=0.0.0.0 \
    PORT=3001 \
    SERVER_PORT=3001 \
    WORKSPACES_ROOT=/home/agent/workspace \
    DATABASE_PATH=/home/agent/.cloudcli/auth.db \
    KEYMGR_DATA_DIR=/home/agent/.claude \
    KEYMGR_PORT=8000 \
    KEYMGR_PROXY_URL=http://127.0.0.1:8000/gw \
    APP_PORT=7860

EXPOSE 7860

USER agent
WORKDIR /home/agent/workspace
CMD ["/usr/local/bin/start.sh"]
