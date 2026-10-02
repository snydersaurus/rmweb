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
./scripts/stage-from-release.sh /path/to/rmweb-0.9.7.tar.gz /path/to/wpewebkit-2.48.5.tar.xz
./scripts/build-wpeqt.sh          # about a minute; output build/rmweb-wpeqt
./scripts/deploy-libby.sh         # rmweb must not be running on the tablet
```

On this Mac Docker Desktop's CLI is at `~/.docker/bin` and may need adding to `PATH`.

## Tablet-side setup that is not in this repo

1. Install the upstream release (`docs/install.md`), then run `scripts/deploy-libby.sh`.
2. **TLS.** The device policy (`/etc/ssl/openssl.cnf.d/10-reduce-tls-ciphers.cnf`) allows only
   ECDHE-ECDSA suites on TLS 1.2, and Libby's API hosts need ECDHE-RSA. Create
   `/home/root/rmweb/openssl-rmweb.cnf`:

   ```ini
   openssl_conf = openssl_init

   [openssl_init]
   ssl_conf = ssl_configuration

   [ssl_configuration]
   system_default = system_default_tls

   [system_default_tls]
   MinProtocol = TLSv1.2
   Ciphersuites = TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_AES_128_CCM_SHA256
   CipherString = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-CCM:ECDHE-ECDSA-AES128-CCM:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-CHACHA20-POLY1305
   ```

   and append `export OPENSSL_CONF=/home/root/rmweb/openssl-rmweb.cnf` to
   `/home/root/rmweb/rmweb-env.sh`. An upstream upgrade replaces that file, so the line has to be
   re-added afterwards.
3. Sign in to Libby once (a setup code from another device works).
4. Reading settings: `bwFast=1` in `/home/root/.rmweb/settings.txt` (or the toolbar's B&W button);
   the Libby entry sets `RMWEB_FULL_EVERY=6` (cleaning flash every 6 presents).

## Using it

- Launch from the **Libby** icon in AppLoad. Over SSH:
  `systemd-run --unit=rmweb-test --collect --setenv=RMWEB_LIBBY=1 --setenv=RMWEB_FULL_EVERY=6 /home/root/rmweb/rmweb https://libbyapp.com/shelf`
- In a book: tap the middle to toggle Libby's controls; swipe or tap an edge to turn pages (only
  with Libby's overlay dismissed); long-press for the toolbar.
- Quit with the X. Quitting restarts xochitl, which asks for the passcode, and drops the book
  from memory.
- Rollback: `/home/root/rmweb/bin/rmweb-wpeqt.orig` is the released binary.

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
