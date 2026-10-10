# Libby wrapper (local fork notes)

This branch (`libby-key-paging`, based on upstream v0.9.7) turns rmweb into a usable reader for
Libby's web app (libbyapp.com) on a **reMarkable Paper Pro Move** (chiappa, 954x1696, OS 3.27.3).
Libby's own reader does the rendering and the loan check; rmweb only changes how input, styling
and sleep reach it. Nothing is written to disk from the book.

## What the branch adds

All in `engine/wpeqt/main.cpp` unless noted.

| Area | Change |
|---|---|
| Page turns | On `libbyapp.com/open/...` swipes (now also horizontal, `gesture.h`) and edge taps send a real Left/Right key through `wpe_view_event`. Libby's reader lives in a cross-origin frame and ignores rmweb's scroll JS. |
| Swipe distances | Scaled to the panel (`gestureParamsFor`: 13% of the width sideways, 11% of the height vertically), and a quick one-way flick counts even when short, so swipes that start on the bezel turn the page. Every non-tap contact is logged as `[gesture]`. |
| Typed notes | Text fields inside Libby's reader frame (the note box) report focus through a small child-frame script; our keyboard opens on the field and Go types the text as real key presses after a select-all. |
| Taps | A tap the JS probe can't resolve is replayed as a real pointer click, so Libby's overlay and in-book controls respond. |
| List scrolling | On other Libby pages a swipe sends a real precise wheel event; the lazy result lists stay blank under the scroll/untrap JS. |
| Search | Go in a search-style field is followed by a real Return key. |
| AppLoad window | With `QTFB_KEY` set (AppLoad, manifest `"qtfb": true`) the view paints into AppLoad's shared framebuffer and reads finger and pen input from its socket; no Qt window, xochitl keeps running, the sleep watcher is off. B&W fast mode maps to qtfb's fast refresh mode with a full refresh every `RMWEB_FULL_EVERY` content presents. Contacts starting in the top 30 px are left to AppLoad's window bar. |
| Pen | In window mode the pen is a real mouse in the page: the button goes down when the tip touches, so a still hold selects a word in Libby and a drag extends the selection (a quick drag is Libby's page swipe). Fingers are ignored while the pen is down. |
| Libby mode | `RMWEB_LIBBY=1`: toolbar is Shelf, B&W/Colour, Font, A-, A+, Refresh (plus X when full-screen). The page is inset below the bar (not inside a book). Long-press summons the bar inside a book. |
| Book font | Font button cycles `kBookFonts`; saved in `<profile>/bookfont.txt`. |
| User files | Optional `<profile>/user.css` and `<profile>/user.js` (all frames). `user.js` can log with `window.webkit.messageHandlers.rmweb.postMessage(...)`. |
| Sleep | Window mode: the reMarkable interface handles sleep. Full-screen mode: power button or 15 idle minutes (`RMWEB_IDLE_SLEEP_MIN`, 0 = never) suspends to RAM. Either way the open book survives, so reading continues offline after wake. |
| Loan guard | Reads the open title's `expireTime` from Libby's `localStorage` and leaves the reader once the loan has ended. |
| TLS option page | When Libby's API hosts refuse the handshake, an in-app page explains the opt-in TLS option. A tap turns it on; in window mode the app sets `OPENSSL_CONF`, ends WebKit's network process (SIGKILL) and reloads, in full-screen mode the launcher restarts the app (exit code 75). |
| Launchers | The icon runs `device/libby-window/libby-window.sh` (AppLoad window, manifest `device/appload/libby/`). `device/libby-entry.sh` is the full-screen launcher, kept for SSH use and as a fallback. |

## Building without rebuilding WebKit

Only `rmweb-wpeqt` is rebuilt. The WebKit libraries come from the upstream release tarball and the
headers are generated from the matching WebKit source tarball.

```sh
./scripts/fetch-sdk.sh
docker build -f toolchain/Dockerfile -t rmweb-sdk .
# rmweb-0.9.7.tar.gz: github.com/exp78/rmweb releases; wpewebkit-2.48.5.tar.xz: wpewebkit.org/releases
./scripts/stage-from-release.sh build/src/rmweb-0.9.7.tar.gz build/src/wpewebkit-2.48.5.tar.xz
./scripts/build-wpeqt.sh          # about a minute; output build/rmweb-wpeqt
./scripts/package-libby.sh        # dist/libby/ and dist/libby-<version>.tar.gz
./scripts/deploy-libby.sh         # rmweb must not be running on the tablet
```

On this Mac Docker Desktop's CLI is at `~/.docker/bin` and may need adding to `PATH`.

## The packaged app

`scripts/package-libby.sh` produces one self-contained AppLoad app folder, `libby/`: the whole
rmweb bundle from the upstream release, this fork's `rmweb-wpeqt`, the launcher, the icon and
manifest, the opt-in TLS config, and upstream's `LICENSE`/`NOTICE`. It installs as
`/home/root/xovi/exthome/appload/libby` and does not need a separate rmweb install. The version
is in `LIBBY_VERSION`.

Install without this repo: unpack the release tarball into AppLoad's folder on the tablet.

```sh
ssh root@10.11.99.1 'tar -C /home/root/xovi/exthome/appload -xzf -' < libby-0.3.1.tar.gz
```

Then restart xochitl through XOVI (or reboot and re-enable XOVI) so AppLoad sees the new icon.

## Tablet-side setup that is not in this repo

1. XOVI and AppLoad must already be installed (for example with reManager/Vellum).
2. **TLS.** Libby's API hosts cannot complete a handshake under the device's system TLS policy.
   The app ships the per-app config but leaves it off. The first time it cannot reach Libby's
   servers it shows a page explaining the option and offers to turn it on; what it changes and
   how to verify and undo it are in [tls.md](tls.md). No script turns it on.
3. Sign in to Libby once (a setup code from another device works).
4. Reading settings: the toolbar's B&W button (`bwFast=1` in `/home/root/.rmweb/settings.txt`);
   the launcher sets `RMWEB_FULL_EVERY=6` (cleaning flash every 6 presents).

The profile (`/home/root/.rmweb`) and WebKit's site data (`/home/root/.local/share/wpe`) are
shared with a plain rmweb install if one exists, so a Libby sign-in carries over.

## Using it

- Launch from the **Libby** icon in AppLoad; it opens as an AppLoad window. The window version
  can only be started by AppLoad (it allocates the framebuffer). The full-screen version can be
  started over SSH:
  `systemd-run --unit=rmweb-test --collect /home/root/xovi/exthome/appload/libby/libby-entry.sh`
- In a book: tap the middle to toggle Libby's controls; swipe or tap an edge to turn pages (only
  with Libby's overlay dismissed); long-press for the toolbar; pen hold-and-drag to highlight.
- Leave with AppLoad's window bar (drag down from the top centre): `_` minimises, `X` closes.
  Closing drops the book from memory; minimising keeps it.
- Logs: `rmweb.log` in the app folder.

## Diagnostics

- `RMWEB_DEBUG_JSFILE=/path`: the file is polled every second and run when it changes. Lines
  starting with `#` are directives (`#key R|L`, `#click x y`, `#wheel x y dy [mode]`,
  `#swipe x1 y1 x2 y2`, `#reload`, `#grab`); the rest is evaluated as JS in the top frame and
  logged as `[js] ...`. Coordinates are view px (panel px / dpr).
- `#grab` / `RMWEB_GRAB_MS` save the composited screen to `/home/root/rmweb/grab.png`.
- `scripts/debug/user-debug.js`: install as `<profile>/user.js` for one test run to log input
  events from every frame and evaluate code posted into them. It evaluates whatever is posted to a
  frame, so **remove it afterwards**.
- xochitl has a start limit (4 starts in 10 minutes triggers an emergency reboot); leave ~10 s
  between a quit and the next launch.

## Known gaps

- Confirmed by hand on the Move: a from-scratch install with reManager (2026-10-02, full-screen);
  in window mode (2026-10-04) the TLS page and in-place reconnect, pen highlights, typed notes,
  bezel swipes, and minimising to a notebook and back with the book still open.
- Full-screen mode's own sleep watcher is confirmed (2026-10-02). The panel regulator refuses
  suspend while its `vpdd` timer runs after a screen update, so it polls `vpdd_timeout_ms` and
  retries. Window mode leaves sleep to the reMarkable interface.
- Offline reading was verified on one 82-page book (84 page turns with wifi off); long books are
  unproven.
- Changing the font with a book open may leave Libby's page breaks slightly off until the book is
  reopened.
- Pen input and pen highlighting exist only in window mode; the full-screen launcher reads
  fingers only.
- AppLoad has no dock: a minimised window is a small bar left on screen, and tapping the icon of a
  running app does not bring it back.
