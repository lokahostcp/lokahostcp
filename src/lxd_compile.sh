#!/bin/bash

branch=${1-main}

apt -y install curl wget

curl https://raw.githubusercontent.com/lokahostcp/lokahostcp/$branch/src/lcp_autocompile.sh > /tmp/lcp_autocompile.sh
chmod +x /tmp/lcp_autocompile.sh

mkdir -p /opt/lokahostcp

# Building Lokahostcp
if bash /tmp/lcp_autocompile.sh --lokahostcp --noinstall --keepbuild $branch; then
	cp /tmp/lokahostcp-src/deb/*.deb /opt/lokahostcp/
fi

# Building PHP
if bash /tmp/lcp_autocompile.sh --php --noinstall --keepbuild $branch; then
	cp /tmp/lokahostcp-src/deb/*.deb /opt/lokahostcp/
fi

# Building NGINX
if bash /tmp/lcp_autocompile.sh --nginx --noinstall --keepbuild $branch; then
	cp /tmp/lokahostcp-src/deb/*.deb /opt/lokahostcp/
fi
