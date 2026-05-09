#!/bin/bash
set -euo pipefail
# ──────────────────────────────────────────────────────────────
# HomePilot Workspace — Custom Startup
# This is APPENDED to the base image's custom_startup.sh.
# ──────────────────────────────────────────────────────────────

echo "=== HomePilot Workspace Startup ==="

# ── Ensure PATH in all shell profiles (idempotent) ───────────
if ! grep -qF 'export PATH="/usr/local/bin:${PATH}"' /home/kasm-user/.bashrc 2>/dev/null; then
    echo 'export PATH="/usr/local/bin:${PATH}"' >> /home/kasm-user/.bashrc
fi
if ! grep -qF 'export PATH="/usr/local/bin:${PATH}"' /home/kasm-user/.profile 2>/dev/null; then
    echo 'export PATH="/usr/local/bin:${PATH}"' >> /home/kasm-user/.profile
fi

# ── Wire HomePilot MCP from env vars ─────────────────────────
# Kasm workspace env vars HP_MCP_URL and HP_MCP_TOKEN must be
# set in the Kasm Admin Panel → Workspace → Environment.
CLAUDE_SETTINGS="/home/kasm-user/.claude/settings.json"
OPENCODE_CONFIG="/home/kasm-user/.config/opencode/opencode.json"

if [ -n "${HP_MCP_URL:-}" ]; then
    # Warn if using plain HTTP to a non-loopback host
    case "$HP_MCP_URL" in
        http://127.*|http://localhost*|https://*)
            ;;
        http://*)
            echo "WARNING: HP_MCP_URL uses plaintext HTTP to a non-local host." >&2
            echo "         Bearer token will be sent in the clear. Use HTTPS in production." >&2
            ;;
    esac

    echo "Wiring HomePilot MCP → $HP_MCP_URL"

    # Create temp files for atomic updates
    TMP_CLAUDE=$(mktemp)
    TMP_OPENCODE=$(mktemp)
    trap 'rm -f "$TMP_CLAUDE" "$TMP_OPENCODE"' EXIT

    if [ -f "$CLAUDE_SETTINGS" ]; then
        if [ -n "${HP_MCP_TOKEN:-}" ]; then
            jq --arg url "$HP_MCP_URL" --arg tok "$HP_MCP_TOKEN" \
                '.mcpServers.homepilot = {"url": $url, "headers": {"Authorization": ("Bearer " + $tok)}}' \
                "$CLAUDE_SETTINGS" > "$TMP_CLAUDE" \
                && mv "$TMP_CLAUDE" "$CLAUDE_SETTINGS"
        else
            jq --arg url "$HP_MCP_URL" \
                '.mcpServers.homepilot = {"url": $url}' \
                "$CLAUDE_SETTINGS" > "$TMP_CLAUDE" \
                && mv "$TMP_CLAUDE" "$CLAUDE_SETTINGS"
        fi
    else
        echo "WARNING: $CLAUDE_SETTINGS not found — skipping Claude Code MCP wiring" >&2
    fi

    if [ -f "$OPENCODE_CONFIG" ]; then
        jq --arg url "$HP_MCP_URL" \
            '.mcp.homepilot = {"type": "remote", "url": $url}' \
            "$OPENCODE_CONFIG" > "$TMP_OPENCODE" \
            && mv "$TMP_OPENCODE" "$OPENCODE_CONFIG"
    else
        echo "WARNING: $OPENCODE_CONFIG not found — skipping OpenCode MCP wiring" >&2
    fi

    echo "  → Claude Code and OpenCode MCP configured"
else
    echo ""
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│  HP_MCP_URL not set — HomePilot MCP not wired.     │"
    echo "│                                                     │"
    echo "│  Set these in Kasm Admin → Workspace → Environment: │"
    echo "│    HP_MCP_URL   = https://<homelab-ip>:8000/mcp    │"
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
