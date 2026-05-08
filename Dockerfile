FROM kasmweb/terminal:1.18.0

# ──────────────────────────────────────────────────────────────
# HomePilot Workspace — Proxmox homelab management
# Base: kasmweb/terminal (xfce4-terminal + KasmVNC, no desktop)
# Tools: hp CLI, Claude Code, OpenCode, uv, gh, dev utilities
# Follows Kasm custom image conventions:
# https://docs.kasm.com/docs/latest/how-to/building_images/
# ──────────────────────────────────────────────────────────────

USER root
ENV HOME=/home/kasm-default-profile
ENV STARTUPDIR=/dockerstartup
ENV INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

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
    python3-venv \
    python3-dev \
    build-essential \
    pkg-config \
    libssl-dev \
    gnupg \
    net-tools \
    dnsutils \
    openssh-client \
    ripgrep \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS (required for Claude Code) ────────────────
RUN curl -fsSL "https://deb.nodesource.com/setup_22.x" | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code

# ── uv (fast Python package manager) ─────────────────────────
ARG UV_VERSION=0.11.8
RUN curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar xz -C /tmp \
    && mv /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv \
    && mv /tmp/uv-x86_64-unknown-linux-gnu/uvx /usr/local/bin/uvx \
    && rm -rf /tmp/uv-x86_64-unknown-linux-gnu

# ── yq (YAML processor) ───────────────────────────────────────
ARG YQ_VERSION=v4.52.5
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
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
RUN curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz" \
    -o /tmp/opencode.tar.gz \
    && tar xzf /tmp/opencode.tar.gz -C /tmp \
    && mv /tmp/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz

# ── homepilot-v2 (hp CLI) in isolated venv ───────────────────
# Pinned to a ref; override at build time with --build-arg HP_REF=<tag>
ARG HP_REF=main
RUN python3 -m venv /opt/hp \
    && /opt/hp/bin/pip install --no-cache-dir \
        "homepilot @ git+https://github.com/mtclab/homepilot-v2.git@${HP_REF}"

ENV PATH="/opt/hp/bin:${PATH}"

# ── OpenCode config ───────────────────────────────────────────
RUN mkdir -p $HOME/.config/opencode
COPY ./config/opencode/opencode.json $HOME/.config/opencode/opencode.json
COPY ./config/opencode/AGENTS.md $HOME/.config/opencode/AGENTS.md

# ── Claude Code MCP config ────────────────────────────────────
RUN mkdir -p $HOME/.claude
COPY ./config/claude/settings.json $HOME/.claude/settings.json

# ── Environment variables for all users ───────────────────────
COPY ./environment /etc/environment
RUN chmod 644 /etc/environment

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
