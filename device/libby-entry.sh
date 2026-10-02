#!/bin/sh
# AppLoad entry point for the "Libby" icon: rmweb opened straight on the Libby shelf.
# Same scope trick as appload-entry.sh (see its header): the launcher stops xochitl, so it must
# not live in xochitl's cgroup.
set -u
R="${RMWEB_ROOT:-/home/root/rmweb}"
URL="https://libbyapp.com/shelf"
# B&W fast mode (settings.txt bwFast=1) skips the per-page quality redraw; this sets how often
# the anti-ghost full flash runs instead (every N content presents, default 100).
export RMWEB_FULL_EVERY="${RMWEB_FULL_EVERY:-6}"
# Libby mode: the reading toolbar (Shelf | B&W/Colour | Font | Refresh | Power) replaces the browser bar.
export RMWEB_LIBBY=1
if command -v systemd-run >/dev/null 2>&1; then
  exec systemd-run --unit=rmweb-appload --scope --quiet --setenv=RMWEB_FULL_EVERY="$RMWEB_FULL_EVERY" --setenv=RMWEB_LIBBY=1 "$R/rmweb" "$URL"
fi
exec "$R/rmweb" "$URL"
