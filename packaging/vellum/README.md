# Vellum package (for reManager / `vellum`)

[reManager](https://github.com/rmitchellscott/reManager) installs software through the
[Vellum](https://github.com/vellum-dev/vellum) package manager. `libby-reader/VELBUILD` is a Vellum
recipe for the Libby app: it downloads the release tarball from this repo and unpacks it into
AppLoad's folder, the same way Vellum's KOReader package does.

**This package is not in Vellum's official index**, so it does not appear in reManager's list of
available packages. It is installed from a file; once installed, reManager shows it under Mods as
`libby-reader`.

## Install the prebuilt package

Each [release](https://github.com/snydersaurus/rmweb/releases) carries
`libby-reader-<version>-r0.apk`. Download it first. The public half of the key the packages are
signed with is kept in this folder, [snydersaurus.rsa.pub](snydersaurus.rsa.pub), not on the
release page, so it does not travel with the file it verifies.

### With the reManager desktop app

1. Open reManager and connect to the tablet.
2. **Utilities** tab, **File Browser**: go to `/home/root` and drag the `.apk` in (or use
   **Upload File**). Wait for the transfer to finish.
3. **Utilities** tab, **Terminal**: install it.

   ```sh
   /home/root/.vellum/bin/vellum add --allow-untrusted /home/root/libby-reader-0.2.1-r0.apk
   ```

   It ends with a line starting `OK:`.
4. In the same terminal, restart the reMarkable interface with XOVI so AppLoad notices the new
   app, and delete the uploaded file:

   ```sh
   rm /home/root/libby-reader-0.2.1-r0.apk
   /home/root/xovi/start
   ```

   The tablet's screen restarts and asks for your passcode if you have one.
5. On the tablet, open AppLoad and tap **Libby**.

### From a terminal on your computer

```sh
scp libby-reader-0.2.1-r0.apk root@10.11.99.1:/home/root/
ssh root@10.11.99.1 '/home/root/.vellum/bin/vellum add --allow-untrusted /home/root/libby-reader-0.2.1-r0.apk \
  && rm /home/root/libby-reader-0.2.1-r0.apk && /home/root/xovi/start'
```

### About `--allow-untrusted`

It installs the package without checking its signature. To have Vellum verify it instead, first
copy [snydersaurus.rsa.pub](snydersaurus.rsa.pub) from this folder to
`/home/root/.vellum/etc/apk/keys/` on the tablet and drop the flag.
That makes Vellum trust anything signed with that key, so only do it if you trust this fork.

The package depends on `launcher`, so Vellum pulls in XOVI and AppLoad if they are missing.

### First launch

1. The app shows a page about one TLS option Libby needs. Tap **Turn it on and restart** if you
   accept it ([docs/tls.md](../../docs/tls.md) explains what it changes). The app comes back by
   itself a few seconds later.
2. Libby asks whether you have a library card. Sign in with your card, or choose to copy from
   another device and enter the code it shows into the Libby app on your phone
   (Menu, Settings, Copy To Another Device).
3. The toolbar along the top is this app's: Shelf, B&W/Colour, Font, A-, A+, Refresh, and X to
   quit. Tap the top of the screen to bring it up, or long-press while a book is open.

### Removing it

`vellum del libby-reader` keeps the log and the TLS choice; `vellum purge libby-reader` clears the
app folder. The browser profile in `/home/root/.rmweb` and the saved Libby sign-in in
`/home/root/.local/share/wpe` are left alone either way.

## Build the package yourself

```sh
./scripts/build-vellum-apk.sh     # dist/vellum/libby-reader-<ver>-r<rel>.apk and the .pub key
```

The recipe fetches the release tarball named by `pkgver`, so publish that release first and update
`pkgver` and `sha512sums` to match. The script explains the Docker arrangement it needs.

## Getting it into reManager's package list

That means a pull request to [vellum-dev/vellum](https://github.com/vellum-dev/vellum) adding
this recipe under `packages/`. Their rules say pull requests must be opened by a person and
commits authored by people, with no assistant co-author lines, and that LLM-written PR
descriptions are closed. Parts of this fork were written with an AI assistant, as its commit
history shows, so that is a conversation to have with the Vellum maintainers, not something to
submit quietly.

## Status

Built with vbuild 0.0.36. On one Paper Pro Move (Vellum 0.3.1, OS 3.27.3), 2026-10-02:
installed with `vellum add --allow-untrusted`, upgraded 0.1.0 to 0.2.0, purged, and then installed
from scratch through the reManager desktop app by a person following the steps above, including
the TLS page and a Libby sign-in by setup code. Verified-signature install is untested.
