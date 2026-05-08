#!/bin/bash
# ──────────────────────────────────────────────────────────────
# HomePilot Workspace — Custom Startup
# This is APPENDED to the base image's custom_startup.sh.
# ──────────────────────────────────────────────────────────────

echo "=== HomePilot Workspace Startup ==="

# ── Ensure PATH in all shell profiles ────────────────────────
cat >> /home/kasm-user/.bashrc << 'ENVVARS'
export PATH="/opt/hp/bin:/usr/local/bin:${PATH}"
ENVVARS

cat >> /home/kasm-user/.profile << 'ENVVARS'
export PATH="/opt/hp/bin:/usr/local/bin:${PATH}"
ENVVARS

# ── Dev override: reinstall editable from repot if present ───
# Allows live edits to homepilot-v2 source without rebuilding image.
HP_DEV_DIR="/home/kasm-user/repot/homepilot-v2"
if [ -d "$HP_DEV_DIR" ]; then
    echo "homepilot-v2 found in repot — installing editable (dev mode)..."
    /opt/hp/bin/pip install --quiet -e "$HP_DEV_DIR" 2>/dev/null \
        && echo "  → dev install ok" \
        || echo "  → dev install failed, using baked version"
fi

# ── HomePilot init check ──────────────────────────────────────
HP_ENV="$HOME/.hp/.env"
if [ ! -f "$HP_ENV" ]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│  HomePilot not configured. To get started:          │"
    echo "│                                                     │"
    echo "│  1. mkdir -p ~/.hp                                  │"
    echo "│  2. Create ~/.hp/.env with at minimum:              │"
    echo "│       HP_SECRET_KEY=<random hex>                    │"
    echo "│       HP_PROXMOX_HOST=<your-proxmox-ip>             │"
    echo "│  3. Run: hp init                                    │"
    echo "│                                                     │"
    echo "│  Generate key: python3 -c                          │"
    echo "│    \"import secrets; print(secrets.token_hex(32))\"  │"
    echo "└─────────────────────────────────────────────────────┘"
    echo ""
fi

# ── Print tool versions ───────────────────────────────────────
echo ""
echo "=== Installed Tools ==="
echo "hp:       $(command -v hp > /dev/null 2>&1 && echo 'installed' || echo 'not found')"
echo "Claude:   $(claude --version 2>/dev/null || echo 'not found')"
echo "OpenCode: $(opencode --version 2>/dev/null || echo 'not found')"
echo "Python:   $(python3 --version 2>/dev/null || echo 'not found')"
echo "uv:       $(uv --version 2>/dev/null || echo 'not found')"
echo "Git:      $(git --version)"
echo "gh:       $(gh --version 2>/dev/null | head -1 || echo 'not found')"
echo "yq:       $(yq --version 2>/dev/null || echo 'not found')"
echo "========================"
echo ""
echo "=== HomePilot Workspace Ready ==="
