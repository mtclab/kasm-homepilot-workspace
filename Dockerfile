FROM kasmweb/terminal:1.18.0

# ──────────────────────────────────────────────────────────────
# HomePilot Workspace — Proxmox homelab management
# Base: kasmweb/terminal (xfce4-terminal + KasmVNC, no desktop)
# Tools: Claude Code, OpenCode, uv, gh, dev utilities
# MCP: connects to a remote homepilot server via HP_MCP_URL
# Follows Kasm custom image conventions:
# https://docs.kasm.com/docs/latest/how-to/building_images/
# ──────────────────────────────────────────────────────────────

USER root
ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Docker BuildKit provides TARGETARCH (amd64 | arm64)
ARG TARGETARCH=amd64

######### Begin Customizations ###########

# ── System packages ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    jq \
    unzip \
    python3 \
    python3-pip \
    gnupg \
    net-tools \
    dnsutils \
    openssh-client \
    ripgrep \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS (required for Claude Code) ────────────────
# Use signed apt repo instead of piping a setup script to bash.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

# ── uv (fast Python package manager) ─────────────────────────
ARG UV_VERSION=0.11.8
RUN case "${TARGETARCH}" in \
        amd64) UV_ARCH="x86_64-unknown-linux-gnu" ;; \
        arm64) UV_ARCH="aarch64-unknown-linux-gnu" ;; \
        *)     echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}.tar.gz" \
       | tar xz -C /tmp \
    && mv "/tmp/uv-${UV_ARCH}/uv" /usr/local/bin/uv \
    && mv "/tmp/uv-${UV_ARCH}/uvx" /usr/local/bin/uvx \
    && rm -rf "/tmp/uv-${UV_ARCH}"

# ── yq (YAML processor) ───────────────────────────────────────
ARG YQ_VERSION=v4.52.5
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" \
    -o /usr/bin/yq && chmod +x /usr/bin/yq

# ── GitHub CLI ────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ── OpenCode (terminal AI coding agent) ──────────────────────
ARG OPENCODE_VERSION=1.14.41
RUN case "${TARGETARCH}" in \
        amd64) OC_ARCH="x64" ;; \
        arm64) OC_ARCH="arm64" ;; \
        *)     echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${OC_ARCH}.tar.gz" \
       -o /tmp/opencode.tar.gz \
    && tar xzf /tmp/opencode.tar.gz -C /tmp \
    && mv /tmp/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz

# ── OpenCode config ───────────────────────────────────────────
RUN mkdir -p $HOME/.config/opencode
COPY ./config/opencode/opencode.json $HOME/.config/opencode/opencode.json
COPY ./config/opencode/AGENTS.md $HOME/.config/opencode/AGENTS.md

# ── Claude Code MCP config ────────────────────────────────────
RUN mkdir -p $HOME/.claude
COPY ./config/claude/settings.json $HOME/.claude/settings.json

######### End Customizations ###########

# ── Kasm post-customization steps (required) ──────────────────
RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

# ── Custom startup script (must come AFTER set_user_permission) ──
COPY ./kasm_startup.sh /tmp/kasm_hp_startup.sh
RUN cat /tmp/kasm_hp_startup.sh >> $STARTUPDIR/custom_startup.sh \
    && chmod +x $STARTUPDIR/custom_startup.sh \
    && rm /tmp/kasm_hp_startup.sh

ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
WORKDIR /home/kasm-user
