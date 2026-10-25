---
title: Claude Code Web
emoji: 🤖
colorFrom: indigo
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# Claude Code Web — all-in-one (single container)

Runs **Claude Code + CloudCLI web UI + the `/admin` provider/key manager** in
one container, on **one port** (default `7860`). Built for Hugging Face Spaces,
Railway, Render, Fly.io, or any single-container host.

```
                    ┌────────────────────────────────────────────┐
  browser  ──:7860──┤ Caddy (reverse proxy)                      │
                    │   /admin*  → key manager  (provider/keys)   │
                    │   /*        → CloudCLI UI (chat, files)     │
                    │                 └→ Claude Code → provider   │
                    └────────────────────────────────────────────┘
```

## Deploy on Hugging Face Spaces

1. Create a new Space → **SDK: Docker** → **Blank**.
2. Upload / push these files (`Dockerfile`, `app.py`, `Caddyfile`,
   `supervisord.conf`, `start.sh`, `README.md`) to the Space repo.
3. The Space builds and serves on `https://<user>-<space>.hf.space`.
4. Open it → set your provider + API key at **`/admin`** → start chatting.

> **Free Spaces are ephemeral** — the filesystem resets on restart. To make your
> provider key **survive restarts for free**, set it as a Space **secret**
> (Settings → Variables and secrets) — the container restores it on boot:
>
> | Name | Kind | Example |
> |---|---|---|
> | `CCW_KEY` | secret | your provider API key |
> | `CCW_BASE_URL` | variable | `https://radoxai.com` |
> | `CCW_PROVIDER` | variable | `radoxai` / `custom` (optional) |
> | `CCW_EXTRA_KEYS` | variable | `key2,key3` (optional, for rotation) |
>
> (CloudCLI's own UI password still resets — set it again, or use Persistent
> Storage (paid) for full persistence.)

## Deploy on a VPS / Railway / Render / Fly

```bash
docker build -t claude-code-space .
docker run -d --name claude-code-space -p 7860:7860 claude-code-space
# open http://<host>:7860  ->  /admin to set your provider
```

Set a different port with `-e APP_PORT=8080 -p 8080:8080`.

## Set your provider (`/admin`)

Open **`/admin`**:

- **Provider** (OpenRouter, DeepSeek, Kimi, Z.ai, MiniMax, Anthropic, Radox, Custom)
- **API Key** (+ optional **extra keys** → multi-key rotation)
- **Test connection** (green/red) · **Load models** · **Save**
- **Saved configs** list with **1-click Use** (switch when a key's limit runs out)

> Anthropic-compatible base URLs: don't add `/v1` (Claude Code appends
> `/v1/messages`). e.g. Radox = `https://radoxai.com`.

## Notes

- **Auth:** CloudCLI asks you to set its own password on first visit. To gate
  `/admin` too, set `KEYMGR_PASSWORD` (env).
- **Agents:** Claude Code is the primary agent. Codex/OpenCode/Cursor are **not**
  included in this minimal image.
- **Graphify** (`/graphify`) is installed if pip succeeded during build.
- This is a **single-container** build — no `docker compose`, no Caddy HTTPS
  (hosts like Spaces/Railway provide HTTPS for you).

## License

MIT (this repo). Bundled components keep their own licenses (CloudCLI UI is
AGPL-3.0-or-later; Docker's base image and Claude Code have their own terms).
