# Changelog

All notable changes to Lokahostcp Control Panel are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-14

Initial release of Lokahostcp Control Panel, derived from the HestiaCP project
(GPLv3). Upstream release history is not reproduced here; see the upstream
repository for the history of the code this fork is based on.

### Added

- `docs/INFRASTRUCTURE.md` — the external services that must exist before an
  install can succeed (package repositories, signing key, IP detection).
- `test/check-references.sh` — verifies that every file and `v-*` command
  referenced by the installers and web UI actually exists in the tree. This
  check exists because the failure it catches shipped silently once already.

### Changed

- Rebranded from HestiaCP to Lokahostcp throughout: install path is now
  `/usr/local/lokahostcp`, environment variables are `LOKAHOSTCP_*`, system
  users are `lokahostcpweb` and `lokahostcpmail`, and packages are
  `lokahostcp`, `lokahostcp-nginx`, `lokahostcp-php`, `lokahostcp-web-terminal`.
- Gettext domain is now `lokahostcp`; all 40 catalogs were rebranded and
  recompiled so existing translations continue to match the new source strings.
- Package repository signing key is now fetched from `pubkey.gpg` alongside the
  repository itself, instead of a hardcoded key ID pulled from a public
  keyserver.
- Version reset to 1.0.0.

### Removed

- Upstream's 1.0.1–1.9.0 upgrade scripts. `func/upgrade.sh` sources every
  version script newer than the installed version, so with `VERSION=1.0.0`
  all of them would have executed against a fresh install.
- Upstream release history from this changelog.

### Fixed

Eight broken references left by an earlier partial rename, where file contents
were rewritten but the files themselves were never renamed, orphaning every
caller:

- `install/common/sudo/hestiaweb` → `lokahostcpweb`. The installers copied
  `sudo/lokahostcpweb`, so the sudoers file was never installed and the web UI
  could not execute any `v-*` command.
- fail2ban `action.d/hestia.conf` and `filter.d/hestia.conf` → `lokahostcp.conf`
  (deb and rpm). `jail.local` declares `filter = lokahostcp` and
  `action = lokahostcp[...]`, so every jail failed to load and brute-force
  protection was inactive. Failed silently.
- Gettext catalogs were named `hestiacp.mo` while `web/inc/i18n.php` requested
  a different domain, so all translations fell back to English. Failed silently.
- `bin/v-change-sys-hestia-ssl` → `v-change-sys-lokahostcp-ssl`, called by
  `web/edit/server/index.php`. Changing the panel SSL certificate failed.
- `bin/v-delete-cron-hestia-autoupdate` → `v-delete-cron-lokahostcp-autoupdate`,
  called by `web/delete/cron/autoupdate/index.php`.
- `install/deb/logrotate/hestia` → `lokahostcp`. The rpm equivalent had already
  been renamed; the deb one had not, so panel logs were never rotated.
- `install/deb/apache2/hestia-event.conf` and `install/rpm/httpd/hestia*.conf`
  → `lokahostcp*.conf`.
- A stale `zh-cn` translation rendered the "Security" label as "Hestia 安全",
  leaking old branding into the Simplified Chinese UI.

[1.0.0]: https://github.com/lokahostcp/lokahostcp/releases/tag/v1.0.0
