#!/bin/bash
# Point package/compile caches at the per-tenant cache volume (/cache) when it is mounted.
if [ -d /cache ] && [ -w /cache ]; then
  mkdir -p /cache/pnpm-store /cache/npm /cache/cargo/registry /cache/cargo/git /cache/sccache /cache/xdg /cache/git /cache/go/mod /cache/go/build /cache/puppeteer /cache/playwright
  for d in registry git; do rm -rf "$HOME/.cargo/$d"; ln -sfn "/cache/cargo/$d" "$HOME/.cargo/$d"; done
  export npm_config_store_dir=/cache/pnpm-store npm_config_cache=/cache/npm SCCACHE_DIR=/cache/sccache \
         XDG_CACHE_HOME=/cache/xdg GOMODCACHE=/cache/go/mod GOCACHE=/cache/go/build \
         PUPPETEER_CACHE_DIR=/cache/puppeteer PLAYWRIGHT_BROWSERS_PATH=/cache/playwright
  # Local Actions cache server (localhost only; data on this tenant's volume).
  mkdir -p /cache/actions-cache
  ( cd /opt/cache-server && HOST=127.0.0.1 NITRO_HOST=127.0.0.1 PORT=3555 NITRO_PORT=3555 NITRO_CLUSTER_WORKERS=1 \
      API_BASE_URL=http://127.0.0.1:3555 STORAGE_DRIVER=filesystem STORAGE_FILESYSTEM_PATH=/cache/actions-cache/blobs \
      DB_DRIVER=sqlite DB_SQLITE_PATH=/cache/actions-cache/db.sqlite CACHE_CLEANUP_OLDER_THAN_DAYS=14 \
      exec node --expose-gc server/index.mjs ) > /tmp/cache-server.log 2>&1 &
  for i in $(seq 50); do curl -s -m1 -o /dev/null http://127.0.0.1:3555/ && break; sleep 0.1; done
  export ACTIONS_RESULTS_URL=http://127.0.0.1:3555/
fi
exec "$@"
