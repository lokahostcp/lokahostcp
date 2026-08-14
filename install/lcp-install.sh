#!/bin/bash

# ======================================================== #
#
# Lokahostcp Control Panel Installation Routine
# Automatic OS detection wrapper
# https://www.lokahost.online/
#
# Currently Supported Operating Systems:
#
# Debian 10, 11, 12
# Ubuntu 20.04, 22.04
# AlmaLinux, EuroLinux, Red Hat EnterPrise Linux, Rocky Linux 8, 9
#
# ======================================================== #

# Where this wrapper fetches the platform installer from.
#
# Both parts are overridable so the installer can be tested against a branch
# before it is promoted, without editing this file:
#
#   LCP_BRANCH=v1.0.0 bash lcp-install.sh
#
# These were previously hardcoded, which meant a wrapper downloaded from one
# branch always pulled its second stage from another. A wrapper should install
# the version it came from unless told otherwise.
LCP_REPO="${LCP_REPO:-lokahostcp/lokahostcp}"
LCP_BRANCH="${LCP_BRANCH:-release}"
LCP_SOURCE="${LCP_SOURCE:-https://raw.githubusercontent.com/$LCP_REPO/$LCP_BRANCH/install}"

# Am I root?
if [ "x$(id -u)" != 'x0' ]; then
	echo 'Error: this script can only be executed by root'
	exit 1
fi

# Check admin user account
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ -z "$1" ]; then
	echo "Error: user admin exists"
	echo
	echo 'Please remove admin user before proceeding.'
	echo 'If you want to do it automatically run installer with -f option:'
	echo "Example: bash $0 --force"
	exit 1
fi

# Check admin group
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ -z "$1" ]; then
	echo "Error: group admin exists"
	echo
	echo 'Please remove admin group before proceeding.'
	echo 'If you want to do it automatically run installer with -f option:'
	echo "Example: bash $0 --force"
	exit 1
fi

# Detect OS
if [ -e "/etc/os-release" ] && [ ! -e "/etc/redhat-release" ]; then
	type=$(grep "^ID=" /etc/os-release | cut -f 2 -d '=')
	if [ "$type" = "ubuntu" ]; then
		# Check if lsb_release is installed
		if [ -e '/usr/bin/lsb_release' ]; then
			release="$(lsb_release -s -r)"
			VERSION='ubuntu'
		else
			echo "lsb_release is currently not installed, please install it:"
			echo "apt-get update && apt-get install lsb-release"
			exit 1
		fi
	elif [ "$type" = "debian" ]; then
		release=$(cat /etc/debian_version | grep -o "[0-9]\{1,2\}" | head -n1)
		VERSION='debian'
	fi
elif [ -e "/etc/os-release" ] && [ -e "/etc/redhat-release" ]; then
	type=$(grep "^ID=" /etc/os-release | cut -f 2 -d '"')
	if [ "$type" = "rhel" ]; then
		release=$(cat /etc/redhat-release | cut -f 1 -d '.' | awk '{print $3}')
		VERSION='rhel'
	elif [ "$type" = "almalinux" ]; then
		release=$(cat /etc/redhat-release | cut -f 1 -d '.' | awk '{print $3}')
		VERSION='almalinux'
	elif [ "$type" = "eurolinux" ]; then
		release=$(cat /etc/redhat-release | cut -f 1 -d '.' | awk '{print $3}')
		VERSION='eurolinux'
	elif [ "$type" = "rocky" ]; then
		release=$(cat /etc/redhat-release | cut -f 1 -d '.' | awk '{print $3}')
		VERSION='rockylinux'
	fi
else
	type="NoSupport"
fi

no_support_message() {
	echo "****************************************************"
	echo "Your operating system (OS) is not supported by"
	echo "Lokahostcp Control Panel. Officially supported releases:"
	echo "****************************************************"
	echo "  Debian 10, 11, 12"
	echo "  Ubuntu 20.04, 22.04 LTS"
	# Commenting this out for now
	# echo "  AlmaLinux, EuroLinux, Red Hat EnterPrise Linux, Rocky Linux 8,9"
	echo ""
	exit 1
}

if [ "$type" = "NoSupport" ]; then
	no_support_message
fi

check_wget_curl() {
	# Check wget
	if [ -e '/usr/bin/wget' ]; then
		if [ -e '/etc/redhat-release' ]; then
			wget -q $LCP_SOURCE/lcp-install-rhel.sh -O lcp-install-rhel.sh
			if [ "$?" -eq '0' ]; then
				bash lcp-install-rhel.sh $*
				exit
			else
				echo "Error: lcp-install-rhel.sh download failed."
				exit 1
			fi
		else
			wget -q $LCP_SOURCE/lcp-install-$type.sh -O lcp-install-$type.sh
			if [ "$?" -eq '0' ]; then
				bash lcp-install-$type.sh $*
				exit
			else
				echo "Error: lcp-install-$type.sh download failed."
				exit 1
			fi
		fi
	fi

	# Check curl
	if [ -e '/usr/bin/curl' ]; then
		if [ -e '/etc/redhat-release' ]; then
			curl -s -O $LCP_SOURCE/lcp-install-rhel.sh
			if [ "$?" -eq '0' ]; then
				bash lcp-install-rhel.sh $*
				exit
			else
				echo "Error: lcp-install-rhel.sh download failed."
				exit 1
			fi
		else
			curl -s -O $LCP_SOURCE/lcp-install-$type.sh
			if [ "$?" -eq '0' ]; then
				bash lcp-install-$type.sh $*
				exit
			else
				echo "Error: lcp-install-$type.sh download failed."
				exit 1
			fi
		fi
	fi
}

# Check for supported operating system before proceeding with download
# of OS-specific installer, and throw error message if unsupported OS detected.
if [[ "$release" =~ ^(10|11|12|20.04|22.04)$ ]]; then
	check_wget_curl $*
elif [[ -e "/etc/redhat-release" ]] && [[ "$release" =~ ^(8|9)$ ]]; then
	check_wget_curl $*
else
	no_support_message
fi

exit
