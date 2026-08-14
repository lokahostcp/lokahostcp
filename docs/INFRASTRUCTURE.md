# Infrastructure requirements

The code in this repository refers to external services that do not exist yet.
Until they do, **`lcp-install-debian.sh` and `lcp-install-ubuntu.sh` cannot
complete** — they fail at the package-installation step.

This file lists every external endpoint the code depends on, what it must
serve, and which files reference it. All hostnames are under
`lokahost.online`.

## Blocking — an install cannot succeed without these

### 1. `apt.lokahost.online` — Debian/Ubuntu package repository

Referenced by `install/lcp-install-debian.sh:18`, `install/lcp-install-ubuntu.sh:18`
(as `RHOST`), and reachability-checked at line 456 before the install proceeds.

Must serve a signed apt repository containing four packages, at the version in
`LOKAHOSTCP_INSTALL_VER` (currently `1.0.0`):

| Package | Built from |
|---|---|
| `lokahostcp` | `src/deb/lokahostcp/` |
| `lokahostcp-nginx` | `src/deb/nginx/` |
| `lokahostcp-php` | `src/deb/php/` |
| `lokahostcp-web-terminal` | `src/deb/web-terminal/` |

The installer requests `lokahostcp=${LOKAHOSTCP_INSTALL_VER}` — an exact
version pin. If the repository does not carry that exact version, the install
aborts.

### 2. GPG signing keypair

The installer now fetches the signing key from the repository itself:

```bash
curl -s "https://$RHOST/pubkey.gpg" | gpg --dearmor | tee /usr/share/keyrings/lokahostcp-keyring.gpg
```

This replaced a hardcoded key ID belonging to the upstream project, which
could never have validated packages signed by this project.

You must:

1. Generate a signing keypair for the project.
2. Sign the apt repository with it.
3. Publish the **public** key at `https://apt.lokahost.online/pubkey.gpg`.
4. Publish the same key at `https://rpm.lokahost.online/RPM-GPG-KEY-LOKAHOSTCP`
   for the yum repository (`install/rpm/lokahostcp/lokahostcp.repo:4`).

Never publish the private key. Only the public half belongs on the web server.

### 3. `ip.lokahost.online` — public IPv4 echo service

Referenced by `bin/v-update-sys-ip:167`, `install/lcp-install-debian.sh:2260`,
`install/lcp-install-ubuntu.sh:2234`:

```bash
pub_ipv4="$(curl -fsLm5 --retry 2 --ipv4 https://ip.lokahost.online/)"
```

Must return the caller's public IPv4 address as plain text. If it does not
resolve, `pub_ipv4` is empty and the server's IP is misdetected, which
cascades into broken vhost and DNS configuration.

See the open decision in `bin/v-update-sys-ip` about the fallback strategy —
this endpoint is a single point of failure as currently written.

### 4. `github.com/lokahostcp/lokahostcp` — source repository

The git-based update path (`bin/v-update-sys-lokahostcp-git`) clones from
here, and failure notifications throughout `bin/` link users to
`/issues`. The repository must exist and be public.

## Non-blocking — referenced but degrade gracefully

| Host | Serves | Referenced by |
|---|---|---|
| `rpm.lokahost.online` | yum repository + `RPM-GPG-KEY-LOKAHOSTCP` | `install/rpm/lokahostcp/lokahostcp.repo` |
| `beta-apt.lokahost.online` | beta channel repo, its own `pubkey.gpg`, and copies of the install scripts | `docs/docs/contributing/testing.md` |
| `storage.lokahost.online` | README screenshot; backup tarballs used by the restore tests | `README.md`, `test/restore.bats` |
| `docs.lokahost.online` | documentation site (built from `docs/`) | `README.md`, `func/upgrade.sh`, installers |
| `forum.lokahost.online` | support forum, linked from upgrade notifications | `README.md`, `CONTRIBUTING.md`, `func/upgrade.sh` |
| `demo.lokahost.online` | public demo instance | `docs/index.md` |
| `translate.lokahost.online` | Crowdin translation portal | `CONTRIBUTING.md` |
| `drone.lokahost.online` | CI build status badge | `README.md` |
| `www.lokahost.online` | project website | `src/rpm/lokahostcp/lokahostcp.spec`, docs |

`test.lokahost.online`, `mx.lokahost.online`, `db.lokahost.online` and
`smartrelay.lokahost.online` appear only as fixture values in the test suite
and do not need to resolve.

## Suggested order

1. Register `lokahost.online` and create the GitHub organisation.
2. Generate the signing keypair.
3. Stand up `apt.lokahost.online` with signed packages and `pubkey.gpg`.
4. Stand up `ip.lokahost.online`, or resolve the fallback decision in
   `bin/v-update-sys-ip` so the dependency is not fatal.
5. Everything else as convenient.
