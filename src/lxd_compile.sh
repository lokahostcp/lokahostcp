#!/bin/bash

branch=${1-main}

apt -y install curl wget

curl https://raw.githubusercontent.com/lokahost/lokahost/$branch/src/lcp_autocompile.sh > /tmp/lcp_autocompile.sh
chmod +x /tmp/lcp_autocompile.sh

mkdir -p /opt/lokahost

# Building Lokahost
if bash /tmp/lcp_autocompile.sh --lokahost --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi

# Building PHP
if bash /tmp/lcp_autocompile.sh --php --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi

# Building NGINX
if bash /tmp/lcp_autocompile.sh --nginx --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi
