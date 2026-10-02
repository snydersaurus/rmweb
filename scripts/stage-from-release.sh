#!/usr/bin/env bash
set -euo pipefail
# Shortcut around the hours-long WPE WebKit build: populate build/stage (what build-wpeqt.sh
# seeds the SDK sysroot from) using the PREBUILT libraries of a release tarball plus headers
# generated from the matching WPE WebKit source tarball. Enough to rebuild rmweb-wpeqt only.
#
#   scripts/stage-from-release.sh <rmweb-X.Y.Z.tar.gz> <wpewebkit-2.48.5.tar.xz>
#
# Headers: WebKit/JSC API headers are generated exactly like the real build does
# (Source/WebKit/Scripts/glib/generate-api-header.py + unifdef, glib-mkenums for the enum
# types); WPEPlatform headers are plain files. libsoup / libwpe / xkbcommon headers come from
# Debian's -dev packages (C API declarations only — the libraries we link are the release's).
cd "$(dirname "$0")/.."
REL="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SRC="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
VER=2.48.5

rm -rf build/stage build/stage-mesa
mkdir -p build/stage/usr/lib/pkgconfig build/stage/usr/include build/stage-mesa/usr build/hdr-src
tar -xzf "$REL" -C build/stage/usr ./lib
tar -xJf "$SRC" -C build/hdr-src --strip-components=1 \
    "wpewebkit-$VER/Source/WebKit/UIProcess/API" \
    "wpewebkit-$VER/Source/WebKit/WPEPlatform" "wpewebkit-$VER/Source/JavaScriptCore/API/glib" \
    "wpewebkit-$VER/Source/WebKit/Scripts/glib"

docker run --rm --platform linux/arm64 -v "$PWD":/work -w /work debian:trixie-slim bash -ec '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -y -qq --no-install-recommends python3 unifdef libglib2.0-dev-bin \
      libsoup-3.0-dev libwpe-1.0-dev libxkbcommon-dev >/dev/null
  S=/work/build/hdr-src/Source
  INC=/work/build/stage/usr/include
  W=$INC/wpe-webkit-2.0
  mkdir -p $W/wpe $W/jsc $W/wpe-platform/wpe/headless
  GEN="python3 $S/WebKit/Scripts/glib/generate-api-header.py WPE"
  FLAGS="-DWTF_PLATFORM_GTK=0 -DWTF_PLATFORM_WPE=1 -DUSE_GTK4=0 -DENABLE_2022_GLIB_API=1 -DENABLE_WPE_PLATFORM=1 -DUSE_GI_FINISH_FUNC_ANNOTATION=0"
  ver() { sed -e "s/@PROJECT_VERSION_MAJOR@/2/" -e "s/@PROJECT_VERSION_MINOR@/48/" -e "s/@PROJECT_VERSION_MICRO@/5/" "$1" > "$2"; }

  # --- WebKit API (wpe/*.h)
  for t in $S/WebKit/UIProcess/API/glib/*.h.in; do
    $GEN "$t" "$W/wpe/$(basename "$t" .in)" /usr/bin/unifdef $FLAGS
  done
  cp $S/WebKit/UIProcess/API/wpe/WebKitColor.h $S/WebKit/UIProcess/API/wpe/WebKitRectangle.h \
     $S/WebKit/UIProcess/API/wpe/WebKitWebViewBackend.h $W/wpe/
  ver $S/WebKit/UIProcess/API/wpe/WebKitVersion.h.in $W/wpe/WebKitVersion.h
  glib-mkenums --template $S/WebKit/UIProcess/API/wpe/WebKitEnumTypes.h.in $W/wpe/*.h \
    | sed s/web_kit/webkit/ | sed s/WEBKIT_TYPE_KIT/WEBKIT_TYPE/ > /tmp/WebKitEnumTypes.h
  mv /tmp/WebKitEnumTypes.h $W/wpe/

  # --- JavaScriptCore GLib API (jsc/*.h)
  for t in $S/JavaScriptCore/API/glib/*.h.in; do
    case "$t" in *JSCVersion.h.in) continue;; esac
    $GEN "$t" "$W/jsc/$(basename "$t" .in)" /usr/bin/unifdef -DENABLE_2022_GLIB_API=1
  done
  cp $S/JavaScriptCore/API/glib/JSCOptions.h $W/jsc/
  ver $S/JavaScriptCore/API/glib/JSCVersion.h.in $W/jsc/JSCVersion.h

  # --- WPEPlatform (wpe-platform/wpe/*.h), headless backend only
  P=$S/WebKit/WPEPlatform/wpe
  for h in WPEEvent WPEBuffer WPEBufferDMABuf WPEBufferDMABufFormats WPEBufferSHM WPEColor WPEDefines \
           WPEDisplay WPEEGLError WPEInputMethodContext WPEKeyUnicode WPEKeymap WPEKeymapXKB WPEKeysyms \
           WPEGestureController WPERectangle WPEScreen WPESettings WPEToplevel WPEView wpe-platform; do
    cp $P/$h.h $W/wpe-platform/wpe/
  done
  cp $P/headless/WPEDisplayHeadless.h $P/headless/WPEToplevelHeadless.h $P/headless/WPEViewHeadless.h \
     $P/headless/wpe-headless.h $W/wpe-platform/wpe/headless/
  ver $P/WPEVersion.h.in $W/wpe-platform/wpe/WPEVersion.h
  sed -e "s|#cmakedefine WPE_PLATFORM_HEADLESS|#define WPE_PLATFORM_HEADLESS|" \
      -e "s|#cmakedefine \(WPE_PLATFORM_[A-Z]*\)|/* #undef \1 */|" $P/WPEConfig.h.in > $W/wpe-platform/wpe/WPEConfig.h
  glib-mkenums --template $P/WPEEnumTypes.h.in $(ls $W/wpe-platform/wpe/*.h | grep -v WPEEnumTypes) \
    | sed s/w_pe/wpe/ | sed s/WPE_TYPE_PE/WPE_TYPE/ | sed s/WPE_TYPEEGL/WPE_TYPE_EGL/ | sed s/wpeegl/wpe_egl/ \
    > $W/wpe-platform/wpe/WPEEnumTypes.h

  # --- third-party C headers the WebKit API pulls in
  cp -a /usr/include/libsoup-3.0 /usr/include/wpe-1.0 $INC/
  [ -d /usr/include/xkbcommon ] && cp -a /usr/include/xkbcommon $INC/xkbcommon   # not in the SDK sysroot
  chown -R '"$(id -u):$(id -g)"' /work/build/stage /work/build/stage-mesa
'

# --- pkg-config files (engine/wpeqt/CMakeLists.txt asks for wpe-webkit-2.0 + wpe-platform-2.0)
PC=build/stage/usr/lib/pkgconfig
cat > $PC/wpe-platform-2.0.pc <<EOF
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: WPE Platform
Description: Platform implementation for WPE WebKit (staged from a release bundle)
Version: $VER
Requires: glib-2.0 gobject-2.0 gio-2.0
Libs: -L\${libdir} -lWPEPlatform-2.0
Cflags: -I\${includedir}/wpe-webkit-2.0/wpe-platform
EOF
cat > $PC/wpe-webkit-2.0.pc <<EOF
prefix=/usr
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: WPE WebKit
Description: Embeddable Web content engine (staged from a release bundle)
Version: $VER
Requires: glib-2.0 gobject-2.0 gio-2.0 wpe-platform-2.0
Libs: -L\${libdir} -lWPEWebKit-2.0
Cflags: -I\${includedir}/wpe-webkit-2.0 -I\${includedir}/libsoup-3.0 -I\${includedir}/wpe-1.0
EOF
echo "[stage] headers: $(find build/stage/usr/include -name '*.h' | wc -l | tr -d ' ')  libs: $(ls build/stage/usr/lib | wc -l | tr -d ' ')"
