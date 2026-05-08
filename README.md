# kasm-homepilot-workspace

A lightweight Kasm Workspaces terminal image for Proxmox homelab management via [homepilot-v2](https://github.com/mtclab/homepilot-v2). Built on `kasmweb/core-ubuntu-noble:1.18.0` (Ubuntu 24.04, headless/terminal), following [Kasm custom image conventions](https://docs.kasm.com/docs/latest/how-to/building_images/).

## What's Included

| Tool | Version | Purpose |
|------|---------|---------|
| homepilot (`hp`) | main | Proxmox homelab management CLI + MCP server |
| Claude Code | latest | Anthropic CLI — MCP client wired to `hp mcp-serve` |
| OpenCode | 1.14.41 | Terminal AI coding agent — MCP client wired to `hp mcp-serve` |
| uv + uvx | 0.11.8 | Fast Python package/project manager |
| Node.js 22 LTS | 22.x | Required by Claude Code |
| GitHub CLI (gh) | latest | GitHub operations |
| yq | 4.52.5 | YAML processor |
| ripgrep, fzf | latest | Fast search utilities |
| curl, wget, jq | latest | HTTP clients and JSON processing |

## MCP Wiring

Both Claude Code and OpenCode are pre-configured to use `hp mcp-serve` (stdio) as their MCP backend:

- **Claude Code**: `~/.claude/settings.json` → `homepilot` MCP server → `/opt/hp/bin/hp mcp-serve`
- **OpenCode**: `~/.config/opencode/opencode.json` → `homepilot` local MCP → `/opt/hp/bin/hp mcp-serve`

This means you can ask Claude or OpenCode to manage your Proxmox cluster directly.

## First-Time Setup

HomePilot requires configuration before use. On first session:

```bash
# 1. Create config directory
mkdir -p ~/.hp

# 2. Generate a secret key
python3 -c "import secrets; print(secrets.token_hex(32))"

# 3. Create ~/.hp/.env
cat > ~/.hp/.env << EOF
HP_SECRET_KEY=<paste generated key>
HP_PROXMOX_HOST=<your-proxmox-ip>
HP_PROXMOX_PORT=8006
HP_PROXMOX_VERIFY_SSL=false
EOF

# 4. Initialize
hp init

# 5. Start coding
claude    # or: opencode
```

## Dev Mode

If `/home/kasm-user/repot/homepilot-v2` exists (persistent storage), startup automatically reinstalls `hp` as an editable dev install so source edits are reflected immediately without rebuilding the image.

## Building & Deploying

### Automated (GitHub Actions)

Push to `main` triggers a build and pushes to GHCR. Manual trigger also available via Actions tab.

Each build produces:
- `ghcr.io/mtclab/kasm-homepilot-workspace:latest`
- `ghcr.io/mtclab/kasm-homepilot-workspace:<commit-sha>`

### Manual

```bash
docker build -t ghcr.io/mtclab/kasm-homepilot-workspace:latest .

# Pin homepilot to a specific tag
docker build --build-arg HP_REF=v2.0.0 -t ghcr.io/mtclab/kasm-homepilot-workspace:v2.0.0 .

echo YOUR_GITHUB_PAT | docker login ghcr.io -u ollikurki --password-stdin
docker push ghcr.io/mtclab/kasm-homepilot-workspace:latest
```

### Add to Kasm Workspaces

1. **Admin Panel** → **Workspaces** → **Add Workspace** → **Custom Image**
2. **Image**: `ghcr.io/mtclab/kasm-homepilot-workspace:latest`
3. Enable **Persistent Storage** so `~/.hp/` config survives between sessions
4. Save and assign to users

> Enable persistent storage — without it `~/.hp/.env` is lost on session end and you re-run setup every time.

## Architecture

```
kasmweb/core-ubuntu-noble:1.18.0  ← Base: Ubuntu 24.04 headless + KasmVNC
  │
  ├── homepilot (hp CLI)  — /opt/hp venv, pinned to HP_REF
  ├── Claude Code          — npm global, MCP → hp mcp-serve
  ├── OpenCode 1.14.41     — binary, MCP → hp mcp-serve
  ├── Node.js 22 LTS       — for Claude Code
  ├── uv + uvx             — Python package manager
  ├── GitHub CLI           — apt repo
  ├── yq                   — binary from GitHub releases
  └── dev utilities        — ripgrep, fzf, curl, wget, jq
```
