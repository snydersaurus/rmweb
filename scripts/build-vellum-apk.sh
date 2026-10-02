#!/usr/bin/env bash
set -euo pipefail
# Build the Vellum package (packaging/vellum/libby-reader/VELBUILD) into an installable .apk with
# Vellum's own build tool, vbuild. The recipe downloads the published release tarball, so the
# release it names must already exist on GitHub.
#
#   scripts/build-vellum-apk.sh        -> dist/vellum/libby-reader-<ver>-r<rel>.apk (+ signing key .pub)
#
# vbuild ships only as an x86_64 Linux binary and drives Docker itself, so it runs here in an
# emulated x86_64 container that talks to the host's Docker socket; its work and key directories
# are mounted at their host paths because the containers vbuild starts see host paths.
# The signing key lives in build/vbuild/home/.config/vbuild/ (not in git): keep it if you want
# later versions to carry the same signature.
cd "$(dirname "$0")/.."
ROOT="$PWD"
B="$ROOT/build/vbuild"
KEY="${VBUILD_KEY_NAME:-snydersaurus}"
VBUILD_VER=0.0.36
WORK="$B/work-$(date +%s)"
mkdir -p "$B/home/.config/vbuild" "$WORK" dist/vellum
[ -x "$B/vbuild-x86_64-musl" ] || {
  gh release download "$VBUILD_VER" -R Eeems/vbuild -p vbuild-x86_64-musl -D "$B" --clobber
  chmod +x "$B/vbuild-x86_64-musl"
}
if [ ! -f "$B/home/.config/vbuild/$KEY.rsa" ]; then
  openssl genrsa -out "$B/home/.config/vbuild/$KEY.rsa" 4096 2>/dev/null
  openssl rsa -in "$B/home/.config/vbuild/$KEY.rsa" -pubout -out "$B/home/.config/vbuild/$KEY.rsa.pub" 2>/dev/null
  chmod 600 "$B/home/.config/vbuild/$KEY.rsa"
fi
cp packaging/vellum/libby-reader/VELBUILD "$WORK/"
docker pull -q --platform linux/amd64 ghcr.io/eeems/vbuild-builder:main >/dev/null
docker run --rm --platform linux/amd64 \
  -v /var/run/docker.sock:/var/run/docker.sock -v "$B:$B" \
  -e HOME="$B/home" -e CARCH=aarch64 -e VBUILD_KEY_NAME="$KEY" -w "$WORK" docker:cli \
  sh -c "apk add -q bash openssl >/dev/null 2>&1; '$B/vbuild-x86_64-musl' all 2>&1 | grep -v 'listxattr'"
cp "$WORK"/dist/aarch64/*.apk dist/vellum/
cp "$B/home/.config/vbuild/$KEY.rsa.pub" dist/vellum/
ls -l dist/vellum
