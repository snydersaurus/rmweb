#!/bin/sh
# AppLoad entry point for the "Libby" icon: rmweb opened straight on the Libby shelf, in Libby mode.
# Works from wherever it is installed: the folder this script sits in is the bundle root, so the
# same file serves the self-contained AppLoad app (scripts/package-libby.sh) and a copy dropped
# into an existing /home/root/rmweb install (scripts/deploy-libby.sh).
# Same scope trick as appload-entry.sh (see its header): the launcher stops xochitl, so it must
# not live in xochitl's cgroup.
set -u
R="$(cd "$(dirname "$0")" && pwd)"
export RMWEB_ROOT="$R"
URL="https://libbyapp.com/shelf"
# Libby mode: the reading toolbar replaces the browser bar.
export RMWEB_LIBBY=1
# B&W fast mode (toolbar button) skips the per-page quality redraw; this sets how often the
# anti-ghost full flash runs instead (every N content presents, default 100).
export RMWEB_FULL_EVERY="${RMWEB_FULL_EVERY:-6}"
# TLS compatibility is opt-in (docs/tls.md): Libby's API hosts need three cipher suites the
# tablet's system policy leaves out. Nothing is loosened unless the owner creates the marker file.
[ -f "$R/tls-compat.on" ] && export OPENSSL_CONF="$R/openssl-rmweb.cnf"
if command -v systemd-run >/dev/null 2>&1; then
  exec systemd-run --unit=rmweb-appload --scope --quiet "$R/rmweb" "$URL"
fi
exec "$R/rmweb" "$URL"
