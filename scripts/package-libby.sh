#!/usr/bin/env bash
set -euo pipefail
# Assemble the self-contained "Libby" AppLoad app: one folder that holds the whole rmweb bundle
# (WebKit + Mesa libraries from an upstream release tarball), this fork's rmweb-wpeqt, the Libby
# launcher, the opt-in TLS config and the licence notices.
#
#   scripts/package-libby.sh [rmweb-X.Y.Z.tar.gz]     (default: build/src/rmweb-0.9.7.tar.gz)
#
# Output: dist/libby/ (install as /home/root/xovi/exthome/appload/libby) and dist/libby-<ver>.tar.gz
# (a tarball, like upstream: lib/ is full of symlinks, which zip tools handle unevenly).
# Build build/rmweb-wpeqt first (scripts/build-wpeqt.sh).
cd "$(dirname "$0")/.."
REL="${1:-build/src/rmweb-0.9.7.tar.gz}"
VER="$(cat LIBBY_VERSION)"
[ -f "$REL" ] || { echo "release tarball not found: $REL" >&2; exit 1; }
[ -f build/rmweb-wpeqt ] || { echo "build/rmweb-wpeqt missing - run scripts/build-wpeqt.sh" >&2; exit 1; }

OUT=dist/libby
rm -rf dist/libby "dist/libby-$VER.tar.gz"
mkdir -p "$OUT"
tar -xzf "$REL" -C "$OUT"
# Not part of the app: upstream's standalone installer and its own AppLoad registration.
rm -rf "$OUT/install.sh" "$OUT/appload" "$OUT/appload-entry.sh" "$OUT/icon.svg"
find "$OUT" -name '._*' -delete          # AppleDouble files that ride along in upstream's tarball

install -m 755 build/rmweb-wpeqt        "$OUT/bin/rmweb-wpeqt"
install -m 755 device/libby-entry.sh    "$OUT/libby-entry.sh"
install -m 755 device/rmweb             "$OUT/rmweb"            # this fork's launcher (restart on exit 75)
install -m 644 device/rmweb-env.sh      "$OUT/rmweb-env.sh"     # ... and env (opt-in TLS marker)
install -m 644 device/openssl-rmweb.cnf "$OUT/openssl-rmweb.cnf"
install -m 644 device/appload/libby/external.manifest.json device/appload/libby/icon.png "$OUT/"
install -m 644 LICENSE NOTICE "$OUT/"
echo "$VER" > "$OUT/LIBBY_VERSION"
sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$VER\"/" "$OUT/external.manifest.json" && rm -f "$OUT/external.manifest.json.bak"
cat > "$OUT/SOURCES" <<SRC
This app: https://github.com/snydersaurus/rmweb (branch libby-key-paging), version $VER
Based on: https://github.com/exp78/rmweb release $(cat "$OUT/VERSION")
The bundled libraries (WPE WebKit, Mesa, libsoup and others) come unmodified from that upstream
release; their licences and source locations are listed in NOTICE.
SRC

COPYFILE_DISABLE=1 tar -C dist -czf "dist/libby-$VER.tar.gz" libby
echo "[package] $OUT  $(du -sh "$OUT" | cut -f1)"
echo "[package] dist/libby-$VER.tar.gz  $(du -h "dist/libby-$VER.tar.gz" | cut -f1)  sha256 $(shasum -a 256 "dist/libby-$VER.tar.gz" | cut -d' ' -f1)"
