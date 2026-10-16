# zectre-runner: GitHub's runner image plus the toolchains our jobs need, baked in because
# isolated runners have no-new-privileges (sudo/apt do not work inside jobs).
FROM ghcr.io/falcondev-oss/github-actions-cache-server:latest AS cacheserver

FROM ghcr.io/actions/actions-runner:latest
# Kept by the nodes' daily image cleanup (zectre-prune): runners must start without a pull.
LABEL zectre.keep=true
USER root
ARG NODE_MAJOR=22
ARG GO_VERSION=1.23.2
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config libssl-dev openssl ca-certificates curl wget git jq unzip zip xz-utils \
      python3 python3-pip python3-venv bc time file rsync openssh-client gnupg lsb-release \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pnpm yarn \
    && curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz \
    && rm -rf /var/lib/apt/lists/*
USER runner
ENV RUSTUP_HOME=/home/runner/.rustup CARGO_HOME=/home/runner/.cargo
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable -c clippy,rustfmt
ENV PATH=/home/runner/.cargo/bin:/usr/local/go/bin:/home/runner/go/bin:$PATH
USER root
COPY git-mirror /usr/local/bin/git
COPY cache-env.sh /usr/local/bin/zectre-cache-env
RUN chmod 755 /usr/local/bin/git /usr/local/bin/zectre-cache-env && apt-get update && apt-get install -y --no-install-recommends util-linux && rm -rf /var/lib/apt/lists/*
# Per-tenant Actions cache: a cache server on localhost inside every runner, storing on the
# tenant's /cache volume. Rebuild its sqlite addon for this image's glibc Node, and rename the
# runner's own ACTIONS_RESULTS_URL so the container's value (pointing at localhost) reaches steps.
COPY --from=cacheserver /app /opt/cache-server
COPY node-wrap /usr/local/lib/zectre-node-wrap
RUN for n in /home/runner/externals/node*/bin/node; do mv "$n" "$n.real" && install -m755 /usr/local/lib/zectre-node-wrap "$n"; done && ls /home/runner/externals/*/bin/
RUN cd /tmp && npm i -s --no-save better-sqlite3@$(node -p "require('/opt/cache-server/server/node_modules/better-sqlite3/package.json').version") \
 && rm -rf /opt/cache-server/server/node_modules/better-sqlite3/build && cp -r node_modules/better-sqlite3/build /opt/cache-server/server/node_modules/better-sqlite3/ \
 && rm -rf /tmp/node_modules /root/.npm \
 && sed -i 's/\x41\x00\x43\x00\x54\x00\x49\x00\x4F\x00\x4E\x00\x53\x00\x5F\x00\x52\x00\x45\x00\x53\x00\x55\x00\x4C\x00\x54\x00\x53\x00\x5F\x00\x55\x00\x52\x00\x4C\x00/\x41\x00\x43\x00\x54\x00\x49\x00\x4F\x00\x4E\x00\x53\x00\x5F\x00\x52\x00\x45\x00\x53\x00\x55\x00\x4C\x00\x54\x00\x53\x00\x5F\x00\x4F\x00\x52\x00\x4C\x00/g' /home/runner/bin/Runner.Worker.dll \
 && grep -c "A.C.T.I.O.N.S._.R.E.S.U.L.T.S._.O.R.L" -a /home/runner/bin/Runner.Worker.dll
# Cross-compile toolchain jobs commonly apt-get (e.g. Rust to Windows via cargo-xwin).
RUN apt-get update && apt-get install -y --no-install-recommends clang lld llvm \
 # Linux desktop (Tauri) build deps, as GitHub-hosted runners provide them via apt.
 dpkg-dev libayatana-appindicator3-dev libgtk-3-dev librsvg2-dev libssl-dev libwebkit2gtk-4.1-dev libxdo-dev patchelf \
 && rm -rf /var/lib/apt/lists/*
# sudo cannot work under no-new-privileges; the shim succeeds for apt installs of baked packages.
COPY sudo-shim /usr/local/bin/sudo
# Replace sudo itself: the runner's PATH puts /usr/bin before /usr/local/bin.
RUN chmod 755 /usr/local/bin/sudo && mv /usr/bin/sudo /usr/bin/sudo.real && ln -s /usr/local/bin/sudo /usr/bin/sudo
# System libraries headless Chrome/Chromium need (puppeteer, playwright), as on GitHub's runners.
RUN npx -y playwright@1.49.1 install-deps chromium && rm -rf /var/lib/apt/lists/* /root/.npm
# GitHub CLI, as on GitHub's hosted runners (release workflows call `gh`).
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh && rm -rf /var/lib/apt/lists/*
# sccache: the real binary in /opt/sccache, and a wrapper pre-seeded in the tool cache for every
# version listed, so sccache-action finds it there (see sccache-wrap).
ARG SCCACHE_VERSIONS="0.18.0 0.17.0 0.16.0 0.15.0 0.14.0 0.13.0 0.12.0 0.11.0 0.10.0"
COPY sccache-wrap /usr/local/lib/zectre-sccache-wrap
RUN v=$(echo $SCCACHE_VERSIONS | cut -d' ' -f1) && mkdir -p /opt/sccache \
 && curl -fsSL https://github.com/mozilla/sccache/releases/download/v$v/sccache-v$v-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /opt/sccache --strip-components=1 sccache-v$v-x86_64-unknown-linux-musl/sccache \
 && chmod 755 /opt/sccache/sccache && /opt/sccache/sccache --version \
 && for ver in $SCCACHE_VERSIONS; do d=/opt/hostedtoolcache/sccache/$ver/x64; mkdir -p $d \
      && install -m755 /usr/local/lib/zectre-sccache-wrap $d/sccache && touch /opt/hostedtoolcache/sccache/$ver/x64.complete; done \
 && chown -R runner:runner /opt/hostedtoolcache
# Node in the tool cache, as on GitHub's runners: actions/setup-node finds a matching version here
# instead of downloading it on every job (~10 s each). Latest of each major the workflows use.
ARG NODE_TOOLCACHE_MAJORS="22 24 26"
RUN idx=$(curl -fsSL https://nodejs.org/dist/index.json) \
 && for m in $NODE_TOOLCACHE_MAJORS; do \
      v=$(echo "$idx" | jq -r --arg p "v$m." '[.[]|select(.version|startswith($p))][0].version' | sed 's/^v//'); \
      [ -n "$v" ] && [ "$v" != null ] || { echo "no Node $m release"; exit 1; }; \
      d=/opt/hostedtoolcache/node/$v/x64; mkdir -p $d \
      && curl -fsSL https://nodejs.org/dist/v$v/node-v$v-linux-x64.tar.xz | tar -xJ -C $d --strip-components=1 \
      && touch /opt/hostedtoolcache/node/$v/x64.complete && echo "toolcache node $v"; \
    done \
 && chown -R runner:runner /opt/hostedtoolcache/node
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache RUNNER_TOOL_CACHE=/opt/hostedtoolcache
USER runner
ENTRYPOINT ["/usr/local/bin/zectre-cache-env"]
RUN node --version && go version && cargo --version && cc --version | head -1 && gh --version | head -1 && ls /opt/hostedtoolcache/node
