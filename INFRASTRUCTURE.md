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

**Status: live, but incomplete — one of four packages is published.**

A signed repository is serving at `https://apt.lokahost.online/` for codenames
`buster`, `bullseye`, `bookworm`, `focal` and `jammy`, on `amd64` and `arm64`.
The full trust chain verifies: `pubkey.gpg` → `InRelease` signature →
`Packages` checksum → `.deb` checksum.

| Package                   | Built from              | Published | Why                                      |
| ------------------------- | ----------------------- | --------- | ---------------------------------------- |
| `lokahostcp`              | `src/deb/lokahostcp/`   | yes       | Pure scripts and web assets, no compiler |
| `lokahostcp-nginx`        | `src/deb/nginx/`        | no        | Compiles nginx from source               |
| `lokahostcp-php`          | `src/deb/php/`          | no        | Compiles PHP from source                 |
| `lokahostcp-web-terminal` | `src/deb/web-terminal/` | no        | `node-pty` is a native module            |

The installer requests `lokahostcp=${LOKAHOSTCP_INSTALL_VER}` — an exact
version pin — plus the other three unpinned. **An install still fails**, at the
package step, until all four are present.

`lokahostcp` is `Architecture: all`, so one build serves both architectures.
The control file previously said `amd64`, which would have made the panel
uninstallable on arm64 regardless of what the repository carried.

#### Building the remaining three

They cannot be built on the current host. It has `gcc`, `g++`, `make` and
`cmake`, but lacks `autoconf`, `bison` and `pkg-config`, and lacks the headers
`zlib.h`, `pcre2.h`, `libxml2`, `sqlite3` and `curl` — installing any of which
needs root. `node-pty` additionally needs `node-gyp` and Node ≥ 18; the host
has Node v12.22.9.

Build them on a machine with root and a full toolchain, once per architecture:

```bash
docker run --rm --platform linux/amd64 -v "$PWD:/src" -w /src debian:bookworm \
	bash src/lcp_autocompile.sh --all
docker run --rm --platform linux/arm64 -v "$PWD:/src" -w /src debian:bookworm \
	bash src/lcp_autocompile.sh --all
```

Then add them to the repository with the procedure in the "Publishing" section
below, and re-sign.

### 2. GPG signing keypair

The installer now fetches the signing key from the repository itself:

```bash
curl -s "https://$RHOST/pubkey.gpg" | gpg --dearmor | tee /usr/share/keyrings/lokahostcp-keyring.gpg
```

This replaced a hardcoded key ID belonging to the upstream project, which
could never have validated packages signed by this project.

**Status: created and published.**

|              |                                                                                 |
| ------------ | ------------------------------------------------------------------------------- |
| Key ID       | `98D8AFF10FDC39E8`                                                              |
| Fingerprint  | `FB8AD618 6336BE7B 7C0957BD 98D8AFF1 0FDC39E8`                                  |
| Identity     | `Lokahostcp Control Panel (Repository Signing Key) <security@lokahost.online>`  |
| Type         | RSA 4096, sign-only                                                             |
| Expires      | 2029-08-14                                                                      |
| Public half  | `https://apt.lokahost.online/pubkey.gpg`                                        |
| Private half | `~/lokahostcp-signing/` on the maintainer's workstation — **not** on any server |

Two things need your attention:

1. **The private key has no passphrase.** That was necessary to script the
   signing. Anyone with read access to that file can sign packages your users
   install as root. Add one with
   `gpg --change-passphrase 98D8AFF10FDC39E8`, accepting that publishing then
   becomes interactive. Back the key up offline; losing it means every existing
   install stops trusting updates.
2. **The RPM repository still needs the same key** exported to
   `https://rpm.lokahost.online/RPM-GPG-KEY-LOKAHOSTCP`, per
   `install/rpm/lokahostcp/lokahostcp.repo:4`.

Never publish the private key. Only the public half belongs on the web server.

#### Publishing

`reprepro` and `aptly` are not installed and need root, so the repository is
generated with `apt-ftparchive`, which is already present. Signing happens on
the workstation that holds the key, never on the web server:

```bash
# On the server, from a directory holding pool/ :
for c in buster bullseye bookworm focal jammy; do
	for a in amd64 arm64; do
		mkdir -p "dists/$c/main/binary-$a"
		apt-ftparchive packages pool/ > "dists/$c/main/binary-$a/Packages"
		gzip -9cn "dists/$c/main/binary-$a/Packages" > "dists/$c/main/binary-$a/Packages.gz"
	done
	apt-ftparchive \
		-o APT::FTPArchive::Release::Origin=Lokahostcp \
		-o APT::FTPArchive::Release::Label=Lokahostcp \
		-o APT::FTPArchive::Release::Suite=stable \
		-o APT::FTPArchive::Release::Codename="$c" \
		-o APT::FTPArchive::Release::Architectures="amd64 arm64" \
		-o APT::FTPArchive::Release::Components=main \
		release "dists/$c" > "dists/$c/Release"
done

# On the workstation, for each codename: fetch Release, then
gpg --local-user 98D8AFF10FDC39E8 --armor --detach-sign -o Release.gpg Release
gpg --local-user 98D8AFF10FDC39E8 --clearsign -o InRelease Release
# ...and upload Release.gpg and InRelease back beside Release.
```

An `Architecture: all` package must appear in **every** per-architecture
`Packages` index, which is why the loop writes the same output to
`binary-amd64` and `binary-arm64`.

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

The repository exists and is public. Its `release` branch is what the
documented install command downloads:

```bash
wget https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install.sh
```

**That branch is stale, and the install it produces fails.** As of the last
check it was pushed 2024-01-30 and still carries pre-rebrand content:

- It refers to `lokahost.com`, not `lokahost.online`.
- Worse, `lcp-install.sh` fetches its second stage from
  `raw.githubusercontent.com/lokahost/lokahost/...` — a **different
  organisation**, which returns 404. So the first stage downloads, then
  immediately fails to fetch the platform installer.

This is the organisation split that was unified in this tree (546 references
moved from `lokahost/lokahost` to `lokahostcp/lokahostcp`). The fix is
published, not local: push this branch to the GitHub `release` branch, which
is currently protected.

Verify afterwards that both stages resolve:

```bash
curl -sI https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install.sh | head -1
curl -sI https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install-debian.sh | head -1
```

The git-based update path (`bin/v-update-sys-lokahostcp-git`) clones from the
same repository, and failure notifications throughout `bin/` link users to
`/issues`.

## Non-blocking — referenced but degrade gracefully

| Host                        | Serves                                                                     | Referenced by                                     |
| --------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------- |
| `rpm.lokahost.online`       | yum repository + `RPM-GPG-KEY-LOKAHOSTCP`                                  | `install/rpm/lokahostcp/lokahostcp.repo`          |
| `beta-apt.lokahost.online`  | beta channel repo, its own `pubkey.gpg`, and copies of the install scripts | `docs/docs/contributing/testing.md`               |
| `storage.lokahost.online`   | README screenshot; backup tarballs used by the restore tests               | `README.md`, `test/restore.bats`                  |
| `docs.lokahost.online`      | documentation site (built from `docs/`)                                    | `README.md`, `func/upgrade.sh`, installers        |
| `forum.lokahost.online`     | support forum, linked from upgrade notifications                           | `README.md`, `CONTRIBUTING.md`, `func/upgrade.sh` |
| `demo.lokahost.online`      | public demo instance                                                       | `docs/index.md`                                   |
| `translate.lokahost.online` | Crowdin translation portal                                                 | `CONTRIBUTING.md`                                 |
| `drone.lokahost.online`     | CI build status badge                                                      | `README.md`                                       |
| `www.lokahost.online`       | project website                                                            | `src/rpm/lokahostcp/lokahostcp.spec`, docs        |

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
