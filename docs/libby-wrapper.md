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
| Taps | A tap the JS probe can't resolve is replayed as a real pointer click, so Libby's overlay and in-book controls respond. |
| List scrolling | On other Libby pages a swipe sends a real precise wheel event; the lazy result lists stay blank under the scroll/untrap JS. |
| Search | Go in a search-style field is followed by a real Return key. |
| Libby mode | `RMWEB_LIBBY=1`: toolbar is Shelf, B&W/Colour, Font, A-, A+, Refresh, X. The page is inset below the bar (not inside a book). Long-press summons the bar inside a book. |
| Book font | Font button cycles `kBookFonts`; saved in `<profile>/bookfont.txt`. |
| User files | Optional `<profile>/user.css` and `<profile>/user.js` (all frames). `user.js` can log with `window.webkit.messageHandlers.rmweb.postMessage(...)`. |
| Sleep | Power button or 15 idle minutes (`RMWEB_IDLE_SLEEP_MIN`, 0 = never) suspends to RAM; the open book survives, so reading continues offline after wake. |
| Loan guard | Reads the open title's `expireTime` from Libby's `localStorage` and leaves the reader once the loan has ended. |
| Launcher | `device/libby-entry.sh` + `device/appload/libby/` = a "Libby" AppLoad icon. |

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
ssh root@10.11.99.1 'tar -C /home/root/xovi/exthome/appload -xzf -' < libby-0.1.0.tar.gz
```

Then restart xochitl through XOVI (or reboot and re-enable XOVI) so AppLoad sees the new icon.

## Tablet-side setup that is not in this repo

1. XOVI and AppLoad must already be installed (for example with reManager/Vellum).
2. **TLS.** Libby's API hosts cannot complete a handshake under the device's system TLS policy.
   The app ships the per-app config but leaves it off; what it changes and how to turn it on,
   verify and undo it are in [tls.md](tls.md). No script turns it on.
3. Sign in to Libby once (a setup code from another device works).
4. Reading settings: the toolbar's B&W button (`bwFast=1` in `/home/root/.rmweb/settings.txt`);
   the launcher sets `RMWEB_FULL_EVERY=6` (cleaning flash every 6 presents).

The profile (`/home/root/.rmweb`) and WebKit's site data (`/home/root/.local/share/wpe`) are
shared with a plain rmweb install if one exists, so a Libby sign-in carries over.

## Using it

- Launch from the **Libby** icon in AppLoad. Over SSH:
  `systemd-run --unit=rmweb-test --collect /home/root/xovi/exthome/appload/libby/libby-entry.sh`
- In a book: tap the middle to toggle Libby's controls; swipe or tap an edge to turn pages (only
  with Libby's overlay dismissed); long-press for the toolbar.
- Quit with the X. Quitting restarts xochitl, which asks for the passcode, and drops the book
  from memory.
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

- Sleep/wake by power button is confirmed (2026-10-02: suspended on the second attempt, woke on
  the power button after 63 s). The panel regulator refuses suspend while its `vpdd` timer runs
  after a screen update, so the watcher polls `vpdd_timeout_ms` and retries; expect a few seconds
  to about half a minute between the press and the actual sleep. Idle sleep is unconfirmed.
- Offline reading was verified on one 82-page book (84 page turns with wifi off); long books are
  unproven.
- Changing the font with a book open may leave Libby's page breaks slightly off until the book is
  reopened.
- Drags are not passed through, so Libby's text selection (highlights, notes) does not work yet.
