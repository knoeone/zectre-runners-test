# zectre-runner: GitHub's runner image plus the toolchains our jobs need, baked in because
# isolated runners have no-new-privileges (sudo/apt do not work inside jobs).
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
USER runner
ENTRYPOINT ["/usr/local/bin/zectre-cache-env"]
RUN node --version && go version && cargo --version && cc --version | head -1
