# TLS on the reMarkable and why Libby needs a per-app config

## The symptom

Libby's pages load, but anything that talks to its API never finishes: the setup-code screen sits
on "generating code" and retries forever. Nothing in rmweb's log says why.

## The cause

reMarkable ships a system-wide OpenSSL policy,
`/etc/ssl/openssl.cnf.d/10-reduce-tls-ciphers.cnf`, written for EU certification (SOG-IS agreed
mechanisms). For TLS 1.2 it allows only ECDHE-**ECDSA** cipher suites.

A server that presents an **RSA** certificate and does not offer TLS 1.3 has no suite in common
with that list, so the handshake is refused. `libbyapp.com` itself negotiates TLS 1.3 and works.
These hosts did not, when tested from a Paper Pro Move on OS 3.27.3 (October 2026):

| Host | System policy | With the config below |
|---|---|---|
| `libbyapp.com` | TLS 1.3, OK | TLS 1.3, OK |
| `sentry.libbyapp.com` | handshake failure | TLS 1.2, ECDHE-RSA-AES256-GCM-SHA384 |
| `vandal.libbyapp.com` | handshake failure | TLS 1.2, ECDHE-RSA-AES256-GCM-SHA384 |
| `thunder.api.overdrive.com` | handshake failure | TLS 1.2, ECDHE-RSA-AES256-GCM-SHA384 |

rmweb's network stack (glib-networking's OpenSSL backend) uses the system OpenSSL and therefore
inherits the policy. BusyBox `wget` on the device has its own TLS code and is not affected, so it
is not a useful test.

## The fix: an opt-in config for rmweb only

`device/openssl-rmweb.cnf` is the system policy's list **plus three suites** for RSA certificates:

```
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-RSA-CHACHA20-POLY1305
```

What it changes and what it does not:

- **Changes:** rmweb will also accept those three suites on TLS 1.2. They are forward-secret AEAD
  suites, the ones mainstream browsers negotiate with most of the web.
- **Does not change:** the TLS 1.2 minimum, the TLS 1.3 suites, certificate verification, or the
  system policy. No other program on the tablet is affected.
- **Deliberately not used:** `CipherString = DEFAULT`, which would also admit CBC suites and
  suites without forward secrecy.

It is a step outside the profile reMarkable certified the device with, for one application. That
is the trade-off; it is why no script in this repo installs it for you.

### Turn it on

**From the app (packaged Libby app, 0.2.0 and later).** In Libby mode the app tries one of the
hosts above once per run. If the handshake is what fails, it shows a page that explains the
option, with "Turn it on and restart" and "Not now". Only a real tap on that page turns it on.
In window mode (0.3.0 and later) the app then restarts only WebKit's network process with the
option applied and reloads the Shelf in the same window; in full-screen mode it restarts itself.
Nothing is changed until that tap.

**By hand.**


**Packaged Libby app** (`/home/root/xovi/exthome/appload/libby`, built by
`scripts/package-libby.sh`): the config ships inside the app but is only used when a marker file
exists. Create the marker:

```sh
ssh root@10.11.99.1 'touch /home/root/xovi/exthome/appload/libby/tls-compat.on'
```

**Plain rmweb install** (`/home/root/rmweb`):

```sh
scp device/openssl-rmweb.cnf root@10.11.99.1:/home/root/rmweb/openssl-rmweb.cnf
ssh root@10.11.99.1 'echo "export OPENSSL_CONF=/home/root/rmweb/openssl-rmweb.cnf" >> /home/root/rmweb/rmweb-env.sh'
```

Restart rmweb afterwards. In the plain install `rmweb-env.sh` is replaced by a new upstream
release, so that line has to be repeated after an upgrade; the packaged app's marker survives
updates.

### Verify

On the tablet, without and then with the config:

```sh
echo | openssl s_client -connect sentry.libbyapp.com:443 -servername sentry.libbyapp.com 2>&1 | grep -E "Cipher is|alert"
echo | OPENSSL_CONF=/home/root/xovi/exthome/appload/libby/openssl-rmweb.cnf openssl s_client -connect sentry.libbyapp.com:443 -servername sentry.libbyapp.com 2>&1 | grep -E "Cipher is|Verification"
```

The first prints a handshake-failure alert; the second prints the negotiated cipher and
`Verification: OK`. To confirm a running rmweb picked it up:

```sh
tr '\0' '\n' < /proc/$(pgrep WPENetworkProc | sed -n 1p)/environ | grep OPENSSL_CONF
```

### Undo

Packaged app: delete `tls-compat.on`. Plain install: delete the `export OPENSSL_CONF=...` line
from `/home/root/rmweb/rmweb-env.sh`. Restart rmweb either way.

## If a host still fails

Run the first `openssl s_client` command against it. An alert with the system policy and success
with the config means the same cause. If it fails either way, the server needs something outside
even this list, or the problem is not TLS.
