#!/bin/sh
# Libby as an AppLoad WINDOW. xochitl keeps running; AppLoad gives us a shared framebuffer
# (QTFB_KEY) and the window's touch and pen input; sleep and the power button stay xochitl's.
# Two layouts: the packaged app (this folder IS the bundle: bin/, lib/, libexec/), or a bare
# experiment folder next to an installed Libby app, borrowing that app's bundle.
set -u
W="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$W/bin/rmweb-wpeqt" ]; then
  R="$W"; BIN="$W/bin/rmweb-wpeqt"
else
  R=/home/root/xovi/exthome/appload/libby; BIN="$W/rmweb-wpeqt"
fi
LOG="$W/rmweb.log"
[ -x "$R/rmweb-env.sh" ] || [ -f "$R/rmweb-env.sh" ] || { echo "[window] no rmweb bundle at $R" >> "$LOG"; exit 1; }
pgrep rmweb-wpeqt >/dev/null 2>&1 && { echo "[window] rmweb is already running" >> "$LOG"; exit 1; }
export RMWEB_ROOT="$R" RMWEB_LIBBY=1
echo "[window] start (QTFB_KEY=${QTFB_KEY:-unset})" >> "$LOG"
# WebKit starts its helper processes from /usr/libexec/wpe-webkit-2.0 and / is read-only: overlay
# it, as the full-screen launcher does. Left mounted on exit (that launcher clears a stale one).
if [ ! -e /usr/libexec/wpe-webkit-2.0 ]; then
  mkdir -p "$W/ovl/upper/wpe-webkit-2.0" "$W/ovl/work"
  cp -a "$R/libexec/wpe-webkit-2.0/." "$W/ovl/upper/wpe-webkit-2.0/"
  mount -t overlay overlay -o "lowerdir=/usr/libexec,upperdir=$W/ovl/upper,workdir=$W/ovl/work" /usr/libexec \
    || { echo "[window] overlay mount failed" >> "$LOG"; exit 1; }
fi
# shellcheck source=/dev/null
. "$R/rmweb-env.sh"
# Optional local tuning (not shipped): KEY=value lines, e.g. RMWEB_CONTENT_PRESENT_MS=300.
# shellcheck source=/dev/null
[ -f "$W/tuning.env" ] && set -a && . "$W/tuning.env" && set +a
# No panel of our own: Qt is only used for painting into the window's framebuffer.
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
exec "$BIN" "https://libbyapp.com/shelf" >> "$LOG" 2>&1
