# ==============================================================================
# agent-base — the shared base image for the OpenCode, OpenChamber and Terminal
# Home Assistant add-ons.
#
# Everything the three add-ons used to install independently lives here once:
# the exact Node toolchain, the full CLI/unix toolset, opencode (certified
# pin), hab, zigporter, ttyd (+ the patched ingress page), yq, the 1Password
# and cosign CLIs, and a pinned snapshot of the skills repo. The add-ons layer
# only their s6 services and app code on top.
#
# The Home Assistant s6/Bashio base is kept as the final stage so add-ons
# built FROM this image stay Supervisor-compatible.
# ==============================================================================

# Global ARGs (available in FROM instructions)
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:trixie
ARG NODE_VERSION=24.21.0

# Home Assistant does not publish a Node-specific Debian base. Keep its s6 and
# Bashio runtime as the final base, and copy an exact official Node toolchain in.
FROM node:${NODE_VERSION}-trixie-slim AS node-runtime

## Build hab CLI from source (pinned release)
# Pinned to the build host's platform — Go cross-compiles via GOARCH below,
# so this stage never needs to run under emulation
FROM --platform=$BUILDPLATFORM golang:1.27-trixie AS hab-builder

ARG HAB_VERSION=1.6.4
ARG TARGETARCH
RUN git clone --depth 1 --branch "${HAB_VERSION}" https://github.com/balloob/home-assistant-build-cli.git /src
WORKDIR /src

# Cross-compile for the target architecture
RUN case "${TARGETARCH}" in amd64|arm64) ;; *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unset}" >&2; exit 1;; esac \
    && GOARCH=${TARGETARCH} \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /hab .

## Main image
FROM ${BUILD_FROM}

# Build arguments
ARG TARGETARCH
ARG NODE_VERSION
# Certified OpenCode runtime. This is a hard pin, never a range or a dist-tag:
# the image ships exactly one OpenCode build, it is the only one any session
# can run, and it changes only through a tested release. The pin is asserted
# against build.yaml by test/pins.test.js so a half-done bump cannot ship.
ARG OPENCODE_VERSION=1.18.31
ARG PPQ_PROXY_VERSION=0.6.0
ARG TSX_VERSION=4.23.13
ARG TTYD_VERSION=1.7.7
ARG YQ_VERSION=v4.53.6
# 1Password CLI, for op:// secret references. Standalone archive from 1Password's
# distribution cache (not in Debian repos), same pinned-release pattern as
# yq/ttyd above.
ARG OP_CLI_VERSION=2.39.0
# sigstore cosign, for OCI image signing/verification from agent sessions —
# the same tool CI uses to keyless-sign the published images.
ARG COSIGN_VERSION=v3.1.3
# Snapshot of the skills repo baked into /opt/skills. Hard-pinned commit: the
# image is rebuilt (and the add-ons follow via the update MR automation) to
# pick up skills changes; a moving ref here would make builds unreproducible.
ARG SKILLS_REF=84c2908e4e092e669581048a47453de4b1c1c75b

# Environment for better Node.js performance
ENV NODE_ENV=production \
    npm_config_update_notifier=false \
    npm_config_fund=false

# HA config dir helpers (hasecret et al.) live in /homeassistant/bin, mounted
# at runtime; prepend it so every shell and agent resolves them unqualified.
ENV PATH="/homeassistant/bin:${PATH}"

RUN case "${TARGETARCH}" in amd64|arm64) ;; *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unset}" >&2; exit 1;; esac

# Install the exact supported Node runtime without replacing Home Assistant's
# Supervisor-compatible base image. npm is shipped with the official Node image.
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -s node /usr/local/bin/nodejs

# Union of the package sets the three add-ons installed individually: editors,
# shells and completions, archive/compression, network inspection, build tools
# (kept permanently — native npm fallback builds need them), python venv
# tooling, and the interactive unix toolset (fzf, bat, zoxide, ...). Apt skips
# what the base already ships.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        arping \
        autoconf \
        automake \
        awscli \
        bash \
        bash-completion \
        bat \
        bats \
        bats-assert \
        bats-file \
        bats-support \
        bc \
        binutils \
        binwalk \
        bubblewrap \
        bzip2 \
        ca-certificates \
        chromium \
        cmake \
        colordiff \
        coreutils \
        curl \
        direnv \
        ffmpeg \
        figlet \
        file \
        findutils \
        fzf \
        g++ \
        gawk \
        gcc \
        gettext \
        gh \
        git \
        glab \
        gnupg \
        gnupg2 \
        graphviz \
        grep \
        grc \
        highlight \
        htop \
        iftop \
        imagemagick \
        ipcalc \
        irssi \
        jo \
        jq \
        libatomic1 \
        libffi-dev \
        libpcre2-dev \
        libpq-dev \
        libtool \
        libyaml-dev \
        links \
        make \
        moreutils \
        mtr \
        ncdu \
        netcat-openbsd \
        ngrep \
        nmap \
        openssh-client \
        openssl \
        p7zip \
        pgbadger \
        pigz \
        pre-commit \
        prettyping \
        procps \
        progress \
        psutils \
        pwgen \
        python3 \
        python3-venv \
        python3-virtualenv \
        python3-virtualenvwrapper \
        python3-yaml \
        rclone \
        rsync \
        shellcheck \
        sqlite3 \
        stow \
        sudo \
        swaks \
        telnet \
        tmux \
        tofrodos \
        tree \
        unzip \
        vim \
        neovim \
        w3m \
        wget \
        xz-utils \
        yamllint \
        zoxide \
    && command -v ssh >/dev/null \
    && command -v ssh-keygen >/dev/null \
    && command -v ssh-keyscan >/dev/null \
    && command -v gh >/dev/null \
    && command -v glab >/dev/null \
    && command -v shellcheck >/dev/null \
    && command -v fzf >/dev/null \
    && test "$(command -v node)" = /usr/local/bin/node \
    && test "$(node --version)" = "v${NODE_VERSION}" \
    && npm --version >/dev/null \
    && rm -rf /var/lib/apt/lists/*

# Chromium path for puppeteer-core (used by screenshot MCP tool)
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Install ttyd from GitHub releases (not in Debian repos)
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") \
    && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ARCH}" -o /usr/bin/ttyd \
    && chmod +x /usr/bin/ttyd

# Install yq (mikefarah) from GitHub releases (static Go binary, not in Debian repos).
# This is the agent's YAML read/query/convert tool: unlike PyYAML or Ruby's YAML, it
# tolerates Home Assistant's custom tags (!include, !secret, !include_dir_*, !env_var,
# !input) instead of crashing on them. Release asset names use Debian arch (amd64/arm64).
# The trailing version assertion fails the build on a truncated/HTML-error download and
# guards against a colliding non-mikefarah "yq" (e.g. the PyPI jq-wrapper) shadowing it.
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && yq --version | grep -q mikefarah

# Install the 1Password CLI (op) from the official standalone archive.
# Self-contained binary; python3's zipfile module extracts it (unzip is not
# needed). The trailing version assertion fails the build on a truncated or
# HTML-error download. Agent shells authenticate it as a service account by
# setting OP_SERVICE_ACCOUNT_TOKEN through the add-on's env_vars option.
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_CLI_VERSION}/op_linux_${ARCH}_v${OP_CLI_VERSION}.zip" -o /tmp/op-cli.zip \
    && python3 -m zipfile -e /tmp/op-cli.zip /tmp/op-cli \
    && install -m 0755 /tmp/op-cli/op /usr/local/bin/op \
    && rm -rf /tmp/op-cli /tmp/op-cli.zip \
    && [ "$(op --version)" = "${OP_CLI_VERSION}" ]

# Install cosign (sigstore) from GitHub releases: OCI image signing and
# verification for agent sessions, matching the keyless signing CI applies to
# the published images. Release asset names use Go arch (amd64/arm64). The
# trailing version assertion fails the build on a truncated/HTML-error
# download.
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${ARCH}" -o /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign \
    && cosign version 2>/dev/null | grep -q "GitVersion:.*${COSIGN_VERSION}"

# Copy hab CLI binary built from source (pinned release)
# A CLI designed for AI agents to manage HA via REST/WebSocket APIs
COPY --from=hab-builder /hab /usr/local/bin/hab

# Install zigporter CLI in an isolated Python virtual environment
# A Zigbee toolkit for cascade-rename, device inspection, and mesh mapping
RUN python3 -m venv /opt/zigporter-venv \
    && /opt/zigporter-venv/bin/pip install --no-cache-dir zigporter \
    && ln -s /opt/zigporter-venv/bin/zigporter /usr/local/bin/zigporter

# Install OpenCode, Prettier, and the PPQ private-mode proxy globally
# - OpenCode: AI coding agent (certified pin; see OPENCODE_VERSION above)
# - Prettier: Code formatter for YAML files, configured for HA conventions
# - ppq-private-mode: local OpenAI-compatible encryption proxy for PPQ TEE models
# - tsx: pinned runtime for the PPQ package's TypeScript entrypoint
# Peer dependencies are omitted because ppq-private-mode is run as a standalone
# proxy, not loaded as an OpenClaw plugin.
#
# The trailing assertion fails the build when the resolved OpenCode is not the
# certified one. A dist-tag or range slipping into OPENCODE_VERSION would
# otherwise publish an image whose runtime nobody tested, and the mismatch would
# surface for the first time on a user's machine. The version is also recorded
# on disk so runtime code can name the certified build without shelling out.
RUN npm install -g --omit=dev --omit=peer --no-audit --no-fund \
        opencode-ai@${OPENCODE_VERSION} \
        prettier \
        ppq-private-mode@${PPQ_PROXY_VERSION} \
        tsx@${TSX_VERSION} \
    && npm cache clean --force \
    && INSTALLED=$(node -e "console.log(require('/usr/local/lib/node_modules/opencode-ai/package.json').version)") \
    && if [ "${INSTALLED}" != "${OPENCODE_VERSION}" ]; then \
        echo "OPENCODE_VERSION is ${OPENCODE_VERSION} but the installed runtime is ${INSTALLED}" >&2; \
        exit 1; \
    fi \
    && printf '%s\n' "${OPENCODE_VERSION}" > /usr/local/share/opencode-certified-version \
    && OPENCODE_ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo "arm64" || echo "x64") \
    && if [ "${OPENCODE_ARCH}" = "arm64" ]; then \
        find /usr/local/lib/node_modules/opencode-ai/node_modules -mindepth 1 -maxdepth 1 -type d \
            ! -name "opencode-linux-arm64" -exec rm -rf {} +; \
    else \
        find /usr/local/lib/node_modules/opencode-ai/node_modules -mindepth 1 -maxdepth 1 -type d \
            ! -name "opencode-linux-x64" ! -name "opencode-linux-x64-baseline" -exec rm -rf {} +; \
    fi \
    && rm -rf /usr/local/lib/node_modules/ppq-private-mode/node_modules/openclaw \
    && find /usr/local/lib/node_modules -type f \( -name '*.d.ts' -o -name '*.map' -o -name '*.pdb' \) -delete \
    && test "$(opencode --version)" = "${OPENCODE_VERSION}"

# Skills repo snapshot at /opt/skills, pinned to SKILLS_REF (see ARG above).
# Refresh interactively with `skills-update`, or bump the pin and release.
RUN git clone --filter=blob:none https://github.com/flapperdeflipper/skills.git /opt/skills \
    && git -C /opt/skills checkout --detach "${SKILLS_REF}" \
    && printf '%s\n' "${SKILLS_REF}" > /usr/local/share/agent-base-skills-ref

# Build the custom ttyd index page (served via -I at runtime): ttyd's page is
# a single self-contained HTML file compiled into the binary, so dump it from
# a briefly-running instance and inject local browser-side fixes for clipboard,
# touch scrolling, and iframe auto-fit. The injector fails the build if the page
# could not be dumped or has an unexpected layout.
COPY ttyd-page/ /opt/ttyd/
RUN set -e; \
    ttyd -p 18099 -i lo bash & \
    TTYD_PID=$!; \
    ok=0; \
    for i in $(seq 1 50); do \
        if curl -fsS -o /tmp/ttyd-index.html http://127.0.0.1:18099/; then ok=1; break; fi; \
        sleep 0.2; \
    done; \
    kill "$TTYD_PID"; \
    [ "$ok" = "1" ]; \
    python3 /opt/ttyd/inject-clipboard.py /tmp/ttyd-index.html /opt/ttyd/index.html /opt/ttyd/clipboard.js /opt/ttyd/touch-scroll.js /opt/ttyd/resize-fit.js; \
    rm -f /tmp/ttyd-index.html

# Shared rootfs: profile.d environment helpers for hab/zigporter, skills-update
COPY rootfs /

RUN chmod +x /usr/local/bin/skills-update \
    && chmod +x /etc/profile.d/hab-esphome.sh \
    && chmod +x /etc/profile.d/zigporter-z2m.sh

# Labels
LABEL \
    org.opencontainers.image.title="agent-base" \
    org.opencontainers.image.description="Shared toolchain base image for the OpenCode, OpenChamber and Terminal Home Assistant add-ons" \
    org.opencontainers.image.source="https://github.com/flapperdeflipper/agent-base" \
    org.opencontainers.image.licenses="MIT"
