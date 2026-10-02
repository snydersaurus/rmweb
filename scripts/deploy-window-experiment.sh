#!/usr/bin/env bash
set -euo pipefail
# EXPERIMENT: install the AppLoad-window variant next to the installed Libby app. Pushes only the
# launcher, manifest, icon and build/rmweb-wpeqt into appload/libby-window; the stable app is not
# touched. A new icon needs xochitl restarted through XOVI (/home/root/xovi/start).
cd "$(dirname "$0")/.."
HOST="${REMARKABLE_HOST:-10.11.99.1}"
A=/home/root/xovi/exthome/appload/libby-window
ssh "root@$HOST" "mkdir -p $A"
scp -q device/libby-window/external.manifest.json device/libby-window/icon.png device/libby-window/libby-window.sh "root@$HOST:$A/"
scp -q build/rmweb-wpeqt "root@$HOST:$A/rmweb-wpeqt.new"
ssh "root@$HOST" "chmod 755 $A/libby-window.sh $A/rmweb-wpeqt.new && mv $A/rmweb-wpeqt.new $A/rmweb-wpeqt && ls -l $A | cut -c1-90"
