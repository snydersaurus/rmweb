#!/usr/bin/env bash
set -euo pipefail
# Push the locally built rmweb-wpeqt (scripts/build-wpeqt.sh) plus the "Libby" AppLoad icon onto
# an existing rmweb install on the tablet. The released binary is kept as rmweb-wpeqt.orig.
# rmweb must NOT be running. The Libby icon shows up after xochitl's next (XOVI) start.
cd "$(dirname "$0")/.."
HOST="${REMARKABLE_HOST:-10.11.99.1}"
R=/home/root/rmweb
A=/home/root/xovi/exthome/appload/libby
ssh "root@$HOST" "pgrep rmweb-wpeqt >/dev/null && { echo 'rmweb is running - quit it first' >&2; exit 1; }
  [ -e $R/bin/rmweb-wpeqt.orig ] || cp -p $R/bin/rmweb-wpeqt $R/bin/rmweb-wpeqt.orig; mkdir -p $A"
scp -q build/rmweb-wpeqt "root@$HOST:$R/bin/rmweb-wpeqt.new"
scp -q device/libby-entry.sh "root@$HOST:$R/libby-entry.sh"
scp -q device/appload/libby/external.manifest.json device/appload/libby/icon.png "root@$HOST:$A/"
ssh "root@$HOST" "chmod 755 $R/bin/rmweb-wpeqt.new $R/libby-entry.sh && mv $R/bin/rmweb-wpeqt.new $R/bin/rmweb-wpeqt && sha256sum $R/bin/rmweb-wpeqt"
shasum -a 256 build/rmweb-wpeqt
