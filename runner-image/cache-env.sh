#!/bin/bash
# Point package/compile caches at the per-tenant cache volume (/cache) when it is mounted.
if [ -d /cache ] && [ -w /cache ]; then
  mkdir -p /cache/pnpm-store /cache/npm /cache/cargo/registry /cache/cargo/git /cache/sccache /cache/xdg /cache/git /cache/go/mod /cache/go/build /cache/puppeteer /cache/playwright
  for d in registry git; do rm -rf "$HOME/.cargo/$d"; ln -sfn "/cache/cargo/$d" "$HOME/.cargo/$d"; done
  export npm_config_store_dir=/cache/pnpm-store npm_config_cache=/cache/npm SCCACHE_DIR=/cache/sccache \
         XDG_CACHE_HOME=/cache/xdg GOMODCACHE=/cache/go/mod GOCACHE=/cache/go/build \
         PUPPETEER_CACHE_DIR=/cache/puppeteer PLAYWRIGHT_BROWSERS_PATH=/cache/playwright
fi
exec "$@"
