#!/bin/sh
# EXPERIMENT (branch appload-window): Libby as an AppLoad WINDOW. xochitl keeps running; AppLoad
# gives us a shared framebuffer (QTFB_KEY) and the window's touch input. This folder holds only the
# launcher, manifest, icon and the experimental rmweb-wpeqt; libraries, helpers and settings come
# from the installed Libby app (the libby-reader package), which is left untouched.
set -u
W="$(cd "$(dirname "$0")" && pwd)"
R=/home/root/xovi/exthome/appload/libby
LOG="$W/rmweb.log"
[ -x "$R/rmweb" ] || { echo "[window] the Libby app is not installed at $R" >> "$LOG"; exit 1; }
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
# No panel of our own: Qt is only used for painting into the window's framebuffer.
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
exec "$W/rmweb-wpeqt" "https://libbyapp.com/shelf" >> "$LOG" 2>&1
