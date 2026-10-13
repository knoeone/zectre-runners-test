# zectre-runner: GitHub's runner image plus the toolchains our jobs need, baked in because
# isolated runners have no-new-privileges (sudo/apt do not work inside jobs).
FROM ghcr.io/falcondev-oss/github-actions-cache-server:latest AS cacheserver

FROM ghcr.io/actions/actions-runner:latest
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
RUN cd /tmp && npm i -s --no-save better-sqlite3@$(node -p "require('/opt/cache-server/server/node_modules/better-sqlite3/package.json').version") \
 && rm -rf /opt/cache-server/server/node_modules/better-sqlite3/build && cp -r node_modules/better-sqlite3/build /opt/cache-server/server/node_modules/better-sqlite3/ \
 && rm -rf /tmp/node_modules /root/.npm \
 && sed -i 's/\x41\x00\x43\x00\x54\x00\x49\x00\x4F\x00\x4E\x00\x53\x00\x5F\x00\x52\x00\x45\x00\x53\x00\x55\x00\x4C\x00\x54\x00\x53\x00\x5F\x00\x55\x00\x52\x00\x4C\x00/\x41\x00\x43\x00\x54\x00\x49\x00\x4F\x00\x4E\x00\x53\x00\x5F\x00\x52\x00\x45\x00\x53\x00\x55\x00\x4C\x00\x54\x00\x53\x00\x5F\x00\x4F\x00\x52\x00\x4C\x00/g' /home/runner/bin/Runner.Worker.dll \
 && grep -c "A.C.T.I.O.N.S._.R.E.S.U.L.T.S._.O.R.L" -a /home/runner/bin/Runner.Worker.dll
USER runner
ENTRYPOINT ["/usr/local/bin/zectre-cache-env"]
RUN node --version && go version && cargo --version && cc --version | head -1
