#!/bin/bash

branch=${1-main}

apt -y install curl wget

curl https://raw.githubusercontent.com/lokahost/lokahost/$branch/src/hst_autocompile.sh > /tmp/hst_autocompile.sh
chmod +x /tmp/hst_autocompile.sh

mkdir -p /opt/lokahost

# Building Lokahost
if bash /tmp/hst_autocompile.sh --lokahost --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi

# Building PHP
if bash /tmp/hst_autocompile.sh --php --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi

# Building NGINX
if bash /tmp/hst_autocompile.sh --nginx --noinstall --keepbuild $branch; then
	cp /tmp/lokahost-src/deb/*.deb /opt/lokahost/
fi
