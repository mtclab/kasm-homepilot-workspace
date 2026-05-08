#!/bin/bash
# ──────────────────────────────────────────────────────────────
# HomePilot Workspace — Custom Startup
# This is APPENDED to the base image's custom_startup.sh.
# ──────────────────────────────────────────────────────────────

echo "=== HomePilot Workspace Startup ==="

# ── Ensure PATH in all shell profiles ────────────────────────
cat >> /home/kasm-user/.bashrc << 'ENVVARS'
export PATH="/usr/local/bin:${PATH}"
ENVVARS

cat >> /home/kasm-user/.profile << 'ENVVARS'
export PATH="/usr/local/bin:${PATH}"
ENVVARS

# ── Wire HomePilot MCP from env vars ─────────────────────────
# Kasm workspace env vars HP_MCP_URL and HP_MCP_TOKEN must be
# set in the Kasm Admin Panel → Workspace → Environment.
CLAUDE_SETTINGS="/home/kasm-user/.claude/settings.json"
OPENCODE_CONFIG="/home/kasm-user/.config/opencode/opencode.json"

if [ -n "$HP_MCP_URL" ]; then
    echo "Wiring HomePilot MCP → $HP_MCP_URL"

    # Claude Code: inject mcpServers.homepilot with optional auth header
    if [ -n "$HP_MCP_TOKEN" ]; then
        jq --arg url "$HP_MCP_URL" --arg tok "$HP_MCP_TOKEN" \
            '.mcpServers.homepilot = {"url": $url, "headers": {"Authorization": ("Bearer " + $tok)}}' \
            "$CLAUDE_SETTINGS" > /tmp/claude_settings.json \
            && mv /tmp/claude_settings.json "$CLAUDE_SETTINGS"
    else
        jq --arg url "$HP_MCP_URL" \
            '.mcpServers.homepilot = {"url": $url}' \
            "$CLAUDE_SETTINGS" > /tmp/claude_settings.json \
            && mv /tmp/claude_settings.json "$CLAUDE_SETTINGS"
    fi

    # OpenCode: inject mcp.homepilot as remote
    jq --arg url "$HP_MCP_URL" \
        '.mcp.homepilot = {"type": "remote", "url": $url}' \
        "$OPENCODE_CONFIG" > /tmp/opencode.json \
        && mv /tmp/opencode.json "$OPENCODE_CONFIG"

    echo "  → Claude Code and OpenCode MCP configured"
else
    echo ""
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│  HP_MCP_URL not set — HomePilot MCP not wired.     │"
    echo "│                                                     │"
    echo "│  Set these in Kasm Admin → Workspace → Environment: │"
    echo "│    HP_MCP_URL   = http://<homelab-ip>:8000/mcp     │"
    echo "│    HP_MCP_TOKEN = <token set on the server>         │"
    echo "│                                                     │"
    echo "│  On the homelab server, start homepilot:            │"
    echo "│    hp mcp-serve --transport http --port 8000        │"
    echo "└─────────────────────────────────────────────────────┘"
    echo ""
fi

# ── Print tool versions ───────────────────────────────────────
echo ""
echo "=== Installed Tools ==="
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
