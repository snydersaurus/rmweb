# rmweb, with a Libby reading mode for the Paper Pro Move

This is a personal fork of [exp78/rmweb](https://github.com/exp78/rmweb) (v0.9.7), a WPE WebKit
browser for reMarkable e-ink tablets. The fork makes Libby's web reader (libbyapp.com) usable on a
**reMarkable Paper Pro Move**, so library loans can be read on the tablet through Libby's own
reader. The same package should also work on the **Paper Pro**, but nobody has tried it there yet:
if you do, please [open an issue](https://github.com/snydersaurus/rmweb/issues) saying how it went.

It is unofficial and not affiliated with OverDrive, Libby or reMarkable. It needs developer mode,
XOVI/AppLoad for the launcher icon, and a library card.

## In short

- **It is only about Libby.** Every change here exists to make reading a Libby loan on the tablet
  pleasant. It is not a better general-purpose browser; for that, use upstream rmweb.
- **It is a personal setup, shared as-is.** One person, one tablet. There is a
  [release](https://github.com/snydersaurus/rmweb/releases) with a ready-built app you unpack
  onto the tablet, or you can build it yourself in about a minute once Docker and the SDK image
  are set up. Either way, expect to use a terminal.
- **The tweaks are small in kind.** rmweb drives pages with scripts; Libby's reader only answers
  to real keys, clicks and scrolls. Most of the fork is passing those through, plus running as an
  AppLoad window, a toolbar, and one opt-in TLS setting the tablet needs before Libby's servers
  will connect.

## What the fork adds

- **Runs as an AppLoad window** next to the normal reMarkable interface, which keeps running. No
  passcode prompt when you leave, the tablet's own sleep and power button work as usual, and a
  minimised Libby keeps your book open while you use your notebooks.
- **Page turns and taps in Libby's reader.** Swipes and edge taps are sent as real arrow keys, and
  taps as real clicks, because the reader ignores rmweb's script-driven scrolling.
- **Pen highlights.** Hold the pen on a word until it highlights, drag, lift, then tap Highlight.
  Highlights and notes are Libby's own, so they sync to your other devices.
- **Working lists and search.** Real scroll events for Libby's self-filling lists; Enter is sent
  after typing into a search box.
- **A reading toolbar** in place of the browser bar: Shelf, B&W/Colour, Font, A-, A+, Refresh.
- **Book font choice**, cycling the typefaces installed on the tablet.
- **Typed notes** into Libby's note box with the on-screen keyboard (tap a highlight, then
  Make a note).
- **Swipes that start on the bezel** still turn the page.
- **Reading on after the connection drops.** Libby's reader loads the whole book when it opens, so
  an open book keeps paging offline, across sleep and while minimised. Closing the app drops it.
- **A build shortcut** that recompiles rmweb's own program in about a minute without building WebKit.

## What it deliberately does not do

- It does not touch DRM, download books, or save any book content to disk. Libby's reader renders
  the book and checks the loan; the book exists only in the open session's memory.
- It leaves the reader when the loan's due date passes.
- It does not switch on the TLS option Libby needs by itself. The app explains it and asks the
  first time Libby cannot connect: see [docs/tls.md](docs/tls.md).

Whether a modified client is acceptable under OverDrive's terms is for each user to judge; the
clauses that come closest concern scraping, extraction and server load.

## Install

You need developer mode on the tablet and the
[reManager](https://github.com/rmitchellscott/reManager) desktop app.

1. Download `libby-reader-<version>-r0.apk` from the
   [latest release](https://github.com/snydersaurus/rmweb/releases/latest).
2. Open reManager and connect to the tablet.
3. **Utilities** tab, **File Browser**: go to `/home/root` and drag the `.apk` in (or use
   **Upload File**).
4. **Utilities** tab, **Terminal**: install it (use the file name you downloaded).

   ```sh
   /home/root/.vellum/bin/vellum add --allow-untrusted /home/root/libby-reader-0.3.1-r0.apk
   ```

5. In the same terminal, delete the uploaded file and restart the reMarkable interface so AppLoad
   notices the new app:

   ```sh
   rm /home/root/libby-reader-0.3.1-r0.apk
   /home/root/xovi/start
   ```

6. On the tablet, open AppLoad and tap **Libby**.

It is not in Vellum's official index, so it will not appear in reManager's list of available
packages; once installed it shows under Mods as `libby-reader`.

**First launch.** The app shows a page about one TLS option Libby needs and turns it on only if
you tap the button ([docs/tls.md](docs/tls.md) explains what it changes); Libby then reconnects in
the same window. Then Libby asks for your library card, or a setup code from the Libby app on your
phone.

**Leaving and coming back.** Drag down from the top centre of the screen for AppLoad's window bar:
`_` minimises Libby (tap `_` on the leftover bar to bring it back, book still open), `X` closes it.
Do not reopen a running Libby from its icon; AppLoad would try to start a second copy.

Other ways to install, signature checking and removal:
[packaging/vellum/README.md](packaging/vellum/README.md). Building it yourself:
[docs/libby-wrapper.md](docs/libby-wrapper.md).

## Status

Tested on one device: Paper Pro Move, OS 3.27.3, against Libby as it was in October 2026. The
Paper Pro is expected to work (the app detects the device and sizes its window to match) but is
untested; the Paper Pro Pure is not supported. Libby's
web app can change at any time and break this. Known gaps are listed at the end of
[docs/libby-wrapper.md](docs/libby-wrapper.md). Upstream's Paper Pro behaviour outside Libby is
meant to be unchanged, but has not been re-tested on a Paper Pro.

The original README follows.

---

# rmweb

A native **WPE WebKit** web browser for the **reMarkable Paper Pro** e-ink tablet.

Compatibility: reMarkable Paper Pro (verified on-device); reMarkable Paper Pro Move (untested -
should work: panel geometry is runtime-derived, testers welcome, see issues).

![start page](docs/screenshots/start-page.png)

> **Status: v0.9.7 - beta.** The primary use case is **reading**; general browsing is basic.
> Implemented and verified on-device: reader mode (Mozilla Readability, light/dark theme), B2 chrome
> painted into the frame (with C++ hit-test and inverted press feedback on every button and key),
> touch input via evdev with a phantom-touch guard, on-screen URL keyboard, bookmarks/history/
> settings persisted in the profile dir, a redesigned HTML start page (`rmweb:` scheme) with letter
> avatars and a tabs-lite open-pages switcher, a **separate settings page** (tap-to-toggle rows,
> applies immediately), page/reader zoom, content blocking (WebKit UserContentManager filter) with
> **cosmetic rules that collapse blocked-ad containers** (no white holes), an e-ink **calm-down
> stylesheet** (kills CSS animations/transitions/smooth scrolling), an **auto-refresh guard** that
> throttles pages reloading themselves while you read, a loading pill with progress and a **stop
> button**, persistent cookies (sqlite - logins survive relaunch), per-URL scroll restore, in-page
> find (`/text` in the address bar), downloads to `~/Downloads` with **PDF/EPUB landing straight
> in the reMarkable library** (visible after quit), form filling (tap a text field →
> on-screen keyboard with its current value, password masked; tap toggles checkbox/radio and cycles
> selects), learn-as-you-type autofill for email/username/name fields (passwords are never
> learned), a per-host password store (obfuscated - NOT encrypted), styled error pages with Retry,
> a TLS padlock, a per-host **continue-anyway for certificate errors** (captive portals on
> hotel/cafe wifi; session-scoped), address-bar search over local bookmarks+history (with a web-search link),
> long-press link peek, a **B&W fast mode** (grayscale present + the fast mono waveform) and a
> **mobile/desktop UA toggle** (both in Settings), a **settle flash** (one full-quality panel develop
> once the page goes quiet - deep black instead of washed-out ACeP grey) and a **text boost** contrast
> toggle (Settings; default on), a KOReader-style reading-progress bar, a coherent **Lucide icon set** drawn
> as vectors (crisp on e-ink, font-independent), a home-screen icon in the stock launcher (XOVI +
> AppLoad), and a no-brick launcher that stops/restores xochitl. E-ink-safe: CPU-only llvmpipe +
> Skia, ~120-250 ms page turns, low RAM.
> A 2026-07-18 code review ([docs/review-2026-07-18.md](docs/review-2026-07-18.md)) found open
> security/robustness issues; the HIGH/CRITICAL items were fixed after it (see git log), but treat
> this as enthusiast-grade beta software, not a hardened product.

## Screenshots

| | | |
|---|---|---|
| ![Wikipedia](docs/screenshots/wikipedia.jpg) | ![e-ink lab](docs/screenshots/eink-lab.png) | ![settings](docs/screenshots/settings.png) |
| Wikipedia | e-ink lab (animations frozen, ad slots collapsed) | Settings page |

More: [loading pill with stop button](docs/screenshots/loading-badge.png)

## Why it's interesting

The Paper Pro's i.MX8M Mini SoC actually has a GPU on die (Vivante GC7000 UltraLite), but the
stock OS ships no driver for it (no `/dev/dri` render node) - so in practice everything renders
on the CPU. rmweb renders the web entirely in software - **Skia CPU raster + Mesa llvmpipe
(software EGL)** - and presents through reMarkable's e-ink display path.

## Architecture (short)

```
input (touch) → shell (hand-painted C++ chrome on a QQuickPaintedItem) → engine (WPE, software GL)
        ARGB8888 frame → display (Qt6 + epaper QPA) → imx-drm → E-Ink 1620×2160
```

The design's five modules folded into `engine/wpeqt` (input/shell/display inside `main.cpp`), plus
`device/` for the on-device glue.
Full design: [`docs/superpowers/specs/2026-06-24-rmweb-browser-design.md`](docs/superpowers/specs/2026-06-24-rmweb-browser-design.md).
Verified hardware facts: [`docs/device-profile.md`](docs/device-profile.md).

## Target device

reMarkable Paper Pro ("Ferrari"), Codex Linux (scarthgap), aarch64, kernel 6.12.49. GPU exists on
the SoC but has no driver in the stock OS, so rendering is **CPU-only**.
Everything installs under `/home/root/rmweb` (the rootfs is full). Cross-compiled with the
official reMarkable "ferrari" Yocto SDK.

## Build & Install

Prebuilt archives on [GitHub Releases](https://github.com/exp78/rmweb/releases) install without any
toolchain - see [`docs/install.md`](docs/install.md).

Building from source needs a `linux/arm64` Docker engine (on macOS: colima + docker-buildx) and the
reMarkable Yocto SDK - setup in [`toolchain/README.md`](toolchain/README.md). The WPE WebKit + Mesa
build takes **hours and tens of GB of disk**.

```bash
./scripts/fetch-sdk.sh                                # download the Yocto SDK once
docker build -f toolchain/Dockerfile -t rmweb-sdk .   # cross-compile image
./scripts/build-wpe.sh deps                           # WPE WebKit deps + Mesa llvmpipe (hours)
./scripts/build-wpe.sh build                          # WPE WebKit itself
./scripts/build-wpeqt.sh                              # build rmweb-wpeqt
./scripts/bundle.sh                                   # create device bundle
./scripts/run-wpeqt-on-device.sh show https://example.com
```

Full instructions: [`docs/install.md`](docs/install.md)

## Roadmap / Planned

Not implemented yet (earlier docs claimed some of these by mistake - see the review above):
on-device JS console, user/content scripts, performance dashboard.

## Credits & License

[MIT](LICENSE) - see the file for details. Third-party components (WPE WebKit, Qt6, Mesa,
Mozilla Readability, Lucide icons, XOVI/AppLoad) and their licenses are listed in
[NOTICE](NOTICE).

Co-developed with AI pair-programming - many thanks to **Claude Code** (Anthropic), **Grok** (xAI)
and **Kimi** (Moonshot AI), who wrote and reviewed large parts of this project.
