#!/usr/bin/env bash
set -euo pipefail
# Install (or update) the self-contained Libby app on the tablet from dist/ (scripts/package-libby.sh).
#
#   scripts/deploy-libby.sh          push the whole app folder (first install, or after repackaging)
#   scripts/deploy-libby.sh --bin    push only build/rmweb-wpeqt into an installed app (quick iteration)
#
# rmweb must NOT be running. Files already in the app folder that the package does not carry
# (rmweb.log, the tls-compat.on marker) are left alone. A new icon shows up after xochitl's next
# (XOVI) start.
cd "$(dirname "$0")/.."
HOST="${REMARKABLE_HOST:-10.11.99.1}"
A=/home/root/xovi/exthome/appload
ssh "root@$HOST" "pgrep rmweb-wpeqt >/dev/null && { echo 'rmweb is running - quit it first' >&2; exit 1; }; mkdir -p $A"
if [ "${1:-}" = "--bin" ]; then
  scp -q build/rmweb-wpeqt "root@$HOST:$A/libby/bin/rmweb-wpeqt.new"
  ssh "root@$HOST" "chmod 755 $A/libby/bin/rmweb-wpeqt.new && mv $A/libby/bin/rmweb-wpeqt.new $A/libby/bin/rmweb-wpeqt && sha256sum $A/libby/bin/rmweb-wpeqt"
  shasum -a 256 build/rmweb-wpeqt
else
  VER="$(cat LIBBY_VERSION)"
  ssh "root@$HOST" "tar -C $A -xzf -" < "dist/libby-$VER.tar.gz"
  ssh "root@$HOST" "cat $A/libby/LIBBY_VERSION; du -sh $A/libby | cut -f1; ls $A/libby/tls-compat.on 2>/dev/null || echo 'TLS compatibility: off (see docs/tls.md)'"
fi
