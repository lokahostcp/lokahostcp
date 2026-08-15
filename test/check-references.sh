#!/bin/bash
# Reference-integrity check.
#
# Verifies that every file and command the installers and web UI point at
# actually exists in this tree.
#
# This exists because a rebrand once rewrote file *contents* without renaming
# the *files*, orphaning eight references. Nothing failed at build or lint
# time; two of the eight failed silently at runtime (dead translations,
# inactive fail2ban jails). Grep could not catch it, because after the sweep
# the tree looked internally consistent.
#
# Exit status: 0 if every reference resolves, 1 if any dangles.
# Run from the repository root: bash test/check-references.sh

cd "$(dirname "$0")/.." || exit 2

FAILED=0
CHECKED=0

fail() {
	printf '  FAIL  %s\n' "$1"
	FAILED=$((FAILED + 1))
}

ok() { CHECKED=$((CHECKED + 1)); }

# Resolve a referenced path, tolerating a trailing slash (directory copy).
exists() {
	[ -e "${1%/}" ]
}

echo "==> installer file references"
for installer in install/lcp-install-debian.sh install/lcp-install-ubuntu.sh; do
	[ -f "$installer" ] || { fail "$installer: missing installer"; continue; }
	# $LOKAHOSTCP_INSTALL_DIR -> install/deb ; $LOKAHOSTCP_COMMON_DIR -> install/common
	grep -oE '\$LOKAHOSTCP_(INSTALL|COMMON)_DIR/[A-Za-z0-9._/-]+' "$installer" \
		| sort -u \
		| while read -r ref; do
			case "$ref" in
			'$LOKAHOSTCP_INSTALL_DIR/'*) path="install/deb/${ref#\$LOKAHOSTCP_INSTALL_DIR/}" ;;
			'$LOKAHOSTCP_COMMON_DIR/'*) path="install/common/${ref#\$LOKAHOSTCP_COMMON_DIR/}" ;;
			*) continue ;;
			esac
			if exists "$path"; then
				echo "ok" >> /tmp/.refcheck.$$
			else
				echo "  FAIL  $installer -> $path (from $ref)" >> /tmp/.refcheck.$$.f
			fi
		done
done
[ -f /tmp/.refcheck.$$ ] && CHECKED=$((CHECKED + $(wc -l < /tmp/.refcheck.$$)))
if [ -f /tmp/.refcheck.$$.f ]; then
	cat /tmp/.refcheck.$$.f
	FAILED=$((FAILED + $(wc -l < /tmp/.refcheck.$$.f)))
fi
rm -f /tmp/.refcheck.$$ /tmp/.refcheck.$$.f

echo "==> v-* commands invoked from the web UI"
for cmd in $(git grep -ohE 'LOKAHOSTCP_CMD \. "v-[a-z0-9-]+' -- 'web/**/*.php' | sed 's/.*"//' | sort -u); do
	# A trailing '-' means PHP concatenates a variable onto the name
	# (e.g. "v-list-web-domain-" . $type . "log"). The name is only known at
	# runtime, so report it for manual review rather than failing on it.
	case "$cmd" in
	*-)
		printf '  note  %s* is built dynamically; verify its variants by hand\n' "$cmd"
		continue
		;;
	esac
	if [ -f "bin/$cmd" ]; then ok; else fail "web UI calls bin/$cmd, which does not exist"; fi
done

echo "==> fail2ban filters and actions declared in jail.local"
for jail in install/deb/fail2ban/jail.local install/rpm/fail2ban/jail.local; do
	[ -f "$jail" ] || continue
	base=$(dirname "$jail")
	for name in $(grep -oE '^filter[[:space:]]*=[[:space:]]*[a-z0-9-]+' "$jail" | awk -F'= *' '{print $2}' | sort -u); do
		# stock fail2ban ships its own filters; only check ones we are meant to provide
		if [ -f "$base/filter.d/$name.conf" ]; then
			ok
		elif [ "$name" = "lokahostcp" ]; then
			fail "$jail declares filter '$name' but $base/filter.d/$name.conf is missing"
		fi
	done
	for name in $(grep -oE '^action[[:space:]]*=[[:space:]]*[a-z0-9-]+' "$jail" | awk -F'= *' '{print $2}' | sort -u); do
		if [ -f "$base/action.d/$name.conf" ]; then ok; else
			fail "$jail declares action '$name' but $base/action.d/$name.conf is missing"
		fi
	done
done

echo "==> gettext domain matches the compiled catalogs"
domain=$(grep -oE '^\$domain = "[^"]+"' web/inc/i18n.php | sed 's/.*"\(.*\)"/\1/')
if [ -z "$domain" ]; then
	fail "could not parse \$domain from web/inc/i18n.php"
else
	missing=0
	for d in web/locale/*/LC_MESSAGES; do
		[ -d "$d" ] || continue
		[ -f "$d/$domain.mo" ] || { fail "$d/$domain.mo missing (domain '$domain')"; missing=$((missing + 1)); }
	done
	[ "$missing" -eq 0 ] && ok
fi

echo "==> upgrade scripts cannot misfire against the shipped version"
shipped=$(grep -oE "^LOKAHOSTCP_INSTALL_VER='[^']+'" install/lcp-install-debian.sh | sed "s/.*'\(.*\)'/\1/")
newer=$(ls install/upgrade/versions/*.sh 2>/dev/null | sed 's|.*/||; s|\.sh$||' \
	| awk -v v="$shipped" '{ if ($0 != v) print }' \
	| sort -V | awk -v v="$shipped" '{ if ($0 > v) print }')
if [ -n "$newer" ]; then
	fail "upgrade scripts newer than shipped version $shipped would run on a fresh install: $(echo "$newer" | tr '\n' ' ')"
else
	ok
fi

echo
if [ "$FAILED" -eq 0 ]; then
	echo "PASS: $CHECKED reference groups resolved, 0 dangling"
	exit 0
fi
echo "FAIL: $FAILED dangling reference(s)"
exit 1
