#!/bin/bash

# Clean installation bootstrap for development purposes only
# Usage:    ./lcp_bootstrap_install.sh [fork] [branch] [os]
# Example:  ./lcp_bootstrap_install.sh lokahost main ubuntu

# Define variables
fork=$1
branch=$2
os=$3

# Download specified installer and compiler
wget https://raw.githubusercontent.com/$fork/lokahost/$branch/install/lcp-install-$os.sh
wget https://raw.githubusercontent.com/$fork/lokahost/$branch/src/lcp_autocompile.sh

# Execute compiler and build lokahost core package
chmod +x lcp_autocompile.sh
./lcp_autocompile.sh --lokahost $branch no

# Execute Lokahost Control Panel installer with default dummy options for testing
if [ -f "/etc/redhat-release" ]; then
	bash lcp-install-$os.sh -f -y no -e admin@test.local -p P@ssw0rd -s lokahost-$branch-$os.test.local --with-rpms /tmp/lokahost-src/rpms
else
	bash lcp-install-$os.sh -f -y no -e admin@test.local -p P@ssw0rd -s lokahost-$branch-$os.test.local --with-debs /tmp/lokahost-src/debs
fi
