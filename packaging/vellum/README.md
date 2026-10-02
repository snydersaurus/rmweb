# Vellum package (for reManager / `vellum`)

[reManager](https://github.com/rmitchellscott/reManager) installs software through the
[Vellum](https://github.com/vellum-dev/vellum) package manager. `libby-reader/VELBUILD` is a Vellum
recipe for the Libby app: it downloads the release tarball from this repo and unpacks it into
AppLoad's folder, the same way Vellum's KOReader package does.

**This package is not in Vellum's official index**, so it does not appear in reManager's package
list. It is installed from a file.

## Install the prebuilt package

Each [release](https://github.com/snydersaurus/rmweb/releases) carries
`libby-reader-<version>-r0.apk` and the public half of the key it is signed with.

```sh
scp libby-reader-0.2.0-r0.apk root@10.11.99.1:/home/root/
ssh root@10.11.99.1 '/home/root/.vellum/bin/vellum add --allow-untrusted /home/root/libby-reader-0.2.0-r0.apk'
```

`--allow-untrusted` installs it without checking the signature. To have Vellum verify it instead,
first copy `snydersaurus.rsa.pub` to `/home/root/.vellum/etc/apk/keys/` on the tablet and drop the
flag. That makes Vellum trust anything signed with that key, so only do it if you trust this fork.

Both steps can be done from inside reManager with its file browser and terminal. The package
depends on `launcher`, so Vellum pulls in XOVI and AppLoad if they are missing.

After installing, restart xochitl through XOVI to get the Libby icon. Libby does not connect
until an opt-in TLS option is on; the app explains it and offers to turn it on the first time it
cannot connect ([docs/tls.md](../../docs/tls.md)).

Remove with `vellum del libby-reader` (keeps the log and the TLS choice) or
`vellum purge libby-reader` (clears the app folder). The browser profile in `/home/root/.rmweb` is
left alone either way.

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

Built with vbuild 0.0.36 and installed with `vellum add --allow-untrusted` on one Paper Pro Move
(Vellum 0.3.1, OS 3.27.3) on 2026-10-02; the app launched afterwards and the TLS marker survived
the install. Verified-signature install and removal are untested.
