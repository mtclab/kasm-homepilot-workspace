# kasm-homepilot-workspace

Lightweight Kasm Workspaces terminal image for Proxmox homelab management via [homepilot-v2](https://github.com/mtclab/homepilot-v2). Built on `kasmweb/terminal:1.18.0` (Ubuntu 24.04, headless/terminal), following [Kasm custom image conventions](https://docs.kasm.com/docs/latest/how-to/building_images/).

**HomePilot is NOT installed in this image.** It runs separately on your homelab server. This workspace connects to it via MCP over HTTP.

## Architecture

```
Kasm Workspace (this image)              Homelab Server
─────────────────────────────            ──────────────────────────────
  Claude Code ──┐                          hp mcp-serve --transport http
  OpenCode    ──┼── HTTP MCP ────────────► (port 8000, /mcp endpoint)
                │   Authorization:              │
                │   Bearer <token>         homepilot DB, vault,
                                           artifacts, Proxmox API
```

MCP wiring is injected at session start from two Kasm workspace env vars:
- **`HP_MCP_URL`** — e.g. `http://homelab.lan:8000/mcp`
- **`HP_MCP_TOKEN`** — bearer token (must match `HP_MCP_TOKEN` on the server)

## What's Included

| Tool | Version | Purpose |
|------|---------|---------|
| Claude Code | latest | Anthropic CLI — MCP client wired to homepilot server |
| OpenCode | 1.14.41 | Terminal AI coding agent — MCP client wired to homepilot server |
| uv + uvx | 0.11.8 | Fast Python package/project manager |
| Node.js 22 LTS | 22.x | Required by Claude Code |
| GitHub CLI (gh) | latest | GitHub operations |
| yq | 4.52.5 | YAML processor |
| ripgrep, fzf | latest | Fast search utilities |
| curl, wget, jq | latest | HTTP clients and JSON processing |

## Setup

### 1. Start HomePilot on your homelab server

HomePilot must be configured and running before sessions connect to it.

```bash
# On the homelab server (one-time setup if not done already)
hp init

# Start the MCP HTTP server
HP_MCP_TOKEN=<your-secret-token> hp mcp-serve --transport http --host 0.0.0.0 --port 8000
```

Run as a systemd service for persistence (see homepilot-v2 docs).

### 2. Configure the Kasm Workspace

In Kasm **Admin Panel** → **Workspaces** → your workspace → **Environment**:

| Variable | Example value |
|----------|--------------|
| `HP_MCP_URL` | `http://192.168.1.10:8000/mcp` |
| `HP_MCP_TOKEN` | `your-secret-token` |

At session start, the startup script injects these into Claude Code and OpenCode MCP configs automatically.

### 3. Start a session

Open the workspace, then:

```bash
claude    # or: opencode
```

Both are pre-wired to the homepilot MCP server. Ask Claude to manage your Proxmox cluster directly.

## Building & Deploying

### Automated (GitHub Actions)

Push to `main` triggers a build and pushes to GHCR. Manual trigger also available via Actions tab.

Each build produces:
- `ghcr.io/mtclab/kasm-homepilot-workspace:latest`
- `ghcr.io/mtclab/kasm-homepilot-workspace:<commit-sha>`

### Manual

```bash
docker build -t ghcr.io/mtclab/kasm-homepilot-workspace:latest .

echo YOUR_GITHUB_PAT | docker login ghcr.io -u ollikurki --password-stdin
docker push ghcr.io/mtclab/kasm-homepilot-workspace:latest
```

### Add to Kasm Workspaces

1. **Admin Panel** → **Workspaces** → **Add Workspace** → **Custom Image**
2. **Image**: `ghcr.io/mtclab/kasm-homepilot-workspace:latest`
3. Add `HP_MCP_URL` and `HP_MCP_TOKEN` under **Environment**
4. Save and assign to users

> Persistent storage is not required — all state lives on the homelab server.

## Image Architecture

```
kasmweb/terminal:1.18.0  ← Base: Ubuntu 24.04 headless + KasmVNC
  │
  ├── Claude Code          — npm global, MCP → HP_MCP_URL at startup
  ├── OpenCode 1.14.41     — binary, MCP → HP_MCP_URL at startup
  ├── Node.js 22 LTS       — for Claude Code
  ├── uv + uvx             — Python package manager
  ├── GitHub CLI           — apt repo
  ├── yq                   — binary from GitHub releases
  └── dev utilities        — ripgrep, fzf, curl, wget, jq
```
