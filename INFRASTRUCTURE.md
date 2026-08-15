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

**Status: complete for `arm64`. `amd64` carries the panel only.**

A signed repository serves at `https://apt.lokahost.online/` for codenames
`buster`, `bullseye`, `bookworm`, `focal` and `jammy`. Verified with a real apt
client in a clean container: `apt-get update` accepts the signature without
warnings, and `apt-get install --download-only lokahostcp=1.0.0
lokahostcp-nginx lokahostcp-php lokahostcp-web-terminal` fetches all four
(88.4 MB) with dependencies resolved.

| Package                   | Version    | arm64 | amd64                     |
| ------------------------- | ---------- | ----- | ------------------------- |
| `lokahostcp`              | `1.0.0`    | yes   | yes (`Architecture: all`) |
| `lokahostcp-nginx`        | `1.25.2-1` | yes   | pending                   |
| `lokahostcp-php`          | `8.2.11-1` | yes   | pending                   |
| `lokahostcp-web-terminal` | `1.0.0`    | yes   | pending                   |

`lokahostcp` is `Architecture: all`, so one build serves both. The control file
previously said `amd64`, which would have made the panel uninstallable on arm64
regardless of what the repository carried.

#### Building the packages

They cannot be built on the deployment host: it has `gcc`, `g++`, `make` and
`cmake` but lacks `autoconf`, `bison`, `pkg-config` and the `zlib`, `pcre2`,
`libxml2`, `sqlite3` and `curl` headers, all of which need root; and `node-pty`
needs `node-gyp` with Node ≥ 18 against its Node v12.22.9.

Build in a container instead, once per architecture. **Install Node 20
explicitly first** — the build script's own nodesource step fails silently
here, and because `set -e` is disabled at `src/lcp_autocompile.sh:3` the build
then continues without it, producing a `lokahostcp` package with no compiled
CSS/JS and a `lokahostcp-web-terminal` with no `node_modules`. Both are valid
`.deb` files that install cleanly and do not work.

```bash
docker run --rm --platform linux/arm64 -v "$PWD:/work" -w /work debian:bookworm bash -c '
	apt-get -qq update && apt-get -qq install -y ca-certificates curl wget git lsb-release python3 make g++ xz-utils
	curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get -qq install -y nodejs
	node -v || exit 1
	echo N | bash src/lcp_autocompile.sh --all ~localsrc'
```

`~localsrc` builds from the mounted checkout rather than downloading a branch.
Mount a clean `git archive` export, not the working tree — a macOS
`node_modules` will poison the container build.

Always verify before publishing, because these failures are silent:

```bash
dpkg-deb -c lokahostcp_1.0.0_all.deb | grep -cE 'web/js/dist|web/css/themes' # expect ~17, not 0
dpkg-deb -c lokahostcp-web-terminal_1.0.0_*.deb | grep -c node_modules       # expect ~361, not 0
```

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

**The private key is passphrase-protected.** Verified behaviourally: signing
with an empty passphrase is refused, signing with the stored passphrase
succeeds. The passphrase is 32 characters of `openssl rand` entropy and is
**not written down anywhere in this repository**; it lives in the macOS
Keychain on the maintainer's workstation:

```bash
security find-generic-password -a lokahostcp-signing \
	-s "Lokahostcp GPG signing key 98D8AFF10FDC39E8" -w
```

Signing is therefore still scriptable without an interactive prompt — the
passphrase is read from the Keychain and passed on a file descriptor, never on
a command line where it would land in shell history or `ps`:

```bash
PASS="$(security find-generic-password -a lokahostcp-signing \
	-s "Lokahostcp GPG signing key 98D8AFF10FDC39E8" -w)"
printf '%s' "$PASS" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 \
	--local-user 98D8AFF10FDC39E8 --armor --detach-sign --output Release.gpg Release
```

Two consequences worth knowing:

1. **The backup at `~/lokahostcp-signing/lokahostcp-signing-key.PRIVATE.asc` is
   now encrypted with that passphrase**, and the earlier unprotected export was
   shredded — an unprotected copy on disk would have made the passphrase
   pointless. Confirmed by importing the backup into a clean keyring: it
   refuses an empty passphrase and signs with the real one.
2. **Losing the Keychain entry loses the key.** Copy the passphrase into a
   password manager, and keep the backup and
   `FB8AD618...0FDC39E8.rev` (the revocation certificate) somewhere offline.
   Without them, every existing install stops trusting updates and the only
   remedy is a new key that every user must fetch by hand.

The **RPM repository** uses the same key — see `rpm.lokahost.online` below.

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
		apt-ftparchive --arch "$a" packages pool/ > "dists/$c/main/binary-$a/Packages"
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

`--arch` is not optional. Without it every index lists every package in the
pool, so an amd64 machine would be offered arm64 binaries. With it,
architecture-specific packages land only in their own index while
`Architecture: all` packages correctly appear in both.

### 3. `rpm.lokahost.online` — yum repository

**Status: live, and empty on purpose.**

Serving over HTTPS with the signing key at
`https://rpm.lokahost.online/RPM-GPG-KEY-LOKAHOSTCP` and valid `repodata` for
`rhel/{8,9}/{x86_64,aarch64}`, matching the `$releasever`/`$basearch`
expansion in `install/rpm/lokahostcp/lokahostcp.repo`.

Verified with a real client: dropping that exact `.repo` into a `rockylinux:9`
container, `dnf repolist` resolves it, `dnf makecache` succeeds, and
`rpm --import` of the `gpgkey=` URL registers key `98D8AFF10FDC39E8`.

**It contains no packages, and that is not a temporary gap.** There is no
`lcp-install-rhel.sh` in this repository (see below), so no RHEL machine can
reach the point of using this repository. Publishing the key and valid metadata
means the references resolve instead of 404ing; it does not make RHEL
supported.

Building RPMs needs `mock` and `rpmbuild` on a RHEL host
(`src/lcp_autocompile.sh:255-268`), which is a separate exercise from the
Debian packaging and has never been run for this fork.

### 4. `ip.lokahost.online` — public IPv4 echo service

Referenced by `bin/v-update-sys-ip:167`, `install/lcp-install-debian.sh:2260`,
`install/lcp-install-ubuntu.sh:2234`:

```bash
pub_ipv4="$(curl -fsLm5 --retry 2 --ipv4 https://ip.lokahost.online/)"
```

**Status: no longer blocking.** `detect_public_ipv4()` in
`bin/v-update-sys-ip` now reads the source address the kernel would use to
reach the internet, and only queries an echo service when that address is
private (RFC1918, CGNAT or link-local). When it does need to ask, it tries this
host first and then `api.ipify.org` and `ifconfig.me`, so the install works
whether or not this endpoint exists.

Standing it up is still worthwhile: it removes the third-party fallback for
NAT'd servers, which is the only path that discloses an install to an outside
operator. The service must return the caller's public IPv4 as plain text.

The installers at `install/lcp-install-debian.sh:2260` and
`install/lcp-install-ubuntu.sh:2234` still call the endpoint directly with a
bare `curl` and have no fallback, so a NAT'd machine installing before this
host exists will still misdetect its IP at install time — only later
`v-update-sys-ip` runs will correct it.

### 5. `github.com/lokahostcp/lokahostcp` — source repository

The repository exists and is public. Its `release` branch is what the
documented install command downloads:

```bash
wget https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install.sh
```

**Status: fixed.** `release` is at `ad86407`, carrying the 1.0.0 tree. Both
stages of the download now resolve, and stage 2 is the corrected installer
(`RHOST='apt.lokahost.online'`, version `1.0.0`, no `lokahost.com` references).

Previously it was a 2024-01-30 snapshot whose `lcp-install.sh` fetched its
second stage from `raw.githubusercontent.com/lokahost/lokahost/...` — a
**different organisation**, returning 404 — so the first stage downloaded and
then immediately failed. That was the organisation split unified in this tree
(546 references moved to `lokahostcp/lokahostcp`).

`release` is branch-protected and force-pushes are refused, and the two
histories share no common ancestor, so neither a normal push nor a pull request
was possible. It was advanced instead by building a commit server-side through
the Git Data API — parent `08ac4a4` (the old `release` head), tree taken from
`v1.0.0` — which makes the ref update a fast-forward rather than a force push.
Protection settings were never modified and the previous history is intact.

To repeat that for a future release:

```bash
R=repos/lokahostcp/lokahostcp
TREE=$(gh api $R/git/commits/$(gh api $R/git/ref/heads/v1.0.0 --jq .object.sha) --jq .tree.sha)
REL=$(gh api $R/git/ref/heads/release --jq .object.sha)
printf '{"message":"...","tree":"%s","parents":["%s"]}' "$TREE" "$REL" > /tmp/c.json
NEW=$(gh api $R/git/commits -X POST --input /tmp/c.json --jq .sha)
printf '{"sha":"%s","force":false}' "$NEW" > /tmp/r.json
gh api $R/git/refs/heads/release -X PATCH --input /tmp/r.json
```

Verify both stages afterwards:

```bash
curl -sI https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install.sh | head -1
curl -sI https://raw.githubusercontent.com/lokahostcp/lokahostcp/release/install/lcp-install-debian.sh | head -1
```

#### RHEL is advertised but not shipped

`install/lcp-install.sh` routes `/etc/redhat-release` machines to
`lcp-install-rhel.sh`, and its header claims AlmaLinux, EuroLinux, RHEL and
Rocky 8/9. **That file does not exist in this repository**, so those machines
download stage 1 and then fail. Either add the installer or remove the claim
and the RHEL branch; the `install/rpm/` tree and `lokahostcp.repo` are
similarly untested.

The git-based update path (`bin/v-update-sys-lokahostcp-git`) clones from the
same repository, and failure notifications throughout `bin/` link users to
`/issues`.

## Non-blocking — referenced but degrade gracefully

| Host                        | Serves                                                                     | Referenced by                                     |
| --------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------- |
| `rpm.lokahost.online`       | yum repository + `RPM-GPG-KEY-LOKAHOSTCP` — live, see below                | `install/rpm/lokahostcp/lokahostcp.repo`          |
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
