#!/bin/bash

# set -e
# Autocompile Script for LokahostCP package Files.
# For building from local source folder use "~localsrc" keyword as hesia branch name,
#   and the script will not try to download the arhive from github, since '~' char is
#   not accepted in branch name.
# Compile but dont install -> ./lcp_autocompile.sh --lokahost --noinstall --keepbuild '~localsrc'
# Compile and install -> ./lcp_autocompile.sh --lokahost --install '~localsrc'

# Clear previous screen output
clear

# Define download function
download_file() {
	local url=$1
	local destination=$2
	local force=$3

	[ "$LOKAHOST_DEBUG" ] && echo >&2 DEBUG: Downloading file "$url" to "$destination"

	# Default destination is the current working directory
	local dstopt=""

	if [ ! -z "$(echo "$url" | grep -E "\.(gz|gzip|bz2|zip|xz)$")" ]; then
		# When an archive file is downloaded it will be first saved localy
		dstopt="--directory-prefix=$ARCHIVE_DIR"
		local is_archive="true"
		local filename="${url##*/}"
		if [ -z "$filename" ]; then
			echo >&2 "[!] No filename was found in url, exiting ($url)"
			exit 1
		fi
		if [ ! -z "$force" ] && [ -f "$ARCHIVE_DIR/$filename" ]; then
			rm -f $ARCHIVE_DIR/$filename
		fi
	elif [ ! -z "$destination" ]; then
		# Plain files will be written to specified location
		dstopt="-O $destination"
	fi
	# check for corrupted archive
	if [ -f "$ARCHIVE_DIR/$filename" ] && [ "$is_archive" = "true" ]; then
		tar -tzf "$ARCHIVE_DIR/$filename" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo >&2 "[!] Archive $ARCHIVE_DIR/$filename is corrupted, redownloading"
			rm -f $ARCHIVE_DIR/$filename
		fi
	fi

	if [ ! -f "$ARCHIVE_DIR/$filename" ]; then
		[ "$LOKAHOST_DEBUG" ] && echo >&2 DEBUG: wget $url -q $dstopt --show-progress --progress=bar:force --limit-rate=3m
		wget $url -q $dstopt --show-progress --progress=bar:force --limit-rate=3m
		if [ $? -ne 0 ]; then
			echo >&2 "[!] Archive $ARCHIVE_DIR/$filename is corrupted and exit script"
			rm -f $ARCHIVE_DIR/$filename
			exit 1
		fi
	fi

	if [ ! -z "$destination" ] && [ "$is_archive" = "true" ]; then
		if [ "$destination" = "-" ]; then
			cat "$ARCHIVE_DIR/$filename"
		elif [ -d "$(dirname $destination)" ]; then
			cp "$ARCHIVE_DIR/$filename" "$destination"
		fi
	fi
}

get_branch_file() {
	local filename=$1
	local destination=$2
	[ "$LOKAHOST_DEBUG" ] && echo >&2 DEBUG: Get branch file "$filename" to "$destination"
	if [ "$use_src_folder" == 'true' ]; then
		if [ -z "$destination" ]; then
			[ "$LOKAHOST_DEBUG" ] && echo >&2 DEBUG: cp -f "$SRC_DIR/$filename" ./
			cp -f "$SRC_DIR/$filename" ./
		else
			[ "$LOKAHOST_DEBUG" ] && echo >&2 DEBUG: cp -f "$SRC_DIR/$filename" "$destination"
			cp -f "$SRC_DIR/$filename" "$destination"
		fi
	else
		download_file "https://raw.githubusercontent.com/$REPO/$branch/$filename" "$destination" $3
	fi
}

usage() {
	echo "Usage:"
	echo "    $0 (--all|--lokahost|--nginx|--php|--web-terminal) [options] [branch] [Y]"
	echo ""
	echo "    --all           Build all lokahost packages."
	echo "    --lokahost        Build only the Control Panel package."
	echo "    --nginx         Build only the backend nginx engine package."
	echo "    --php           Build only the backend php engine package"
	echo "    --web-terminal  Build only the backend web terminal websocket package"
	echo "  Options:"
	echo "    --install       Install generated packages"
	echo "    --keepbuild     Don't delete downloaded source and build folders"
	echo "    --cross         Compile lokahost package for both AMD64 and ARM64"
	echo "    --debug         Debug mode"
	echo ""
	echo "For automated builds and installations, you may specify the branch"
	echo "after one of the above flags. To install the packages, specify 'Y'"
	echo "following the branch name."
	echo ""
	echo "Example: bash lcp_autocompile.sh --lokahost develop Y"
	echo "This would install a Lokahost Control Panel package compiled with the"
	echo "develop branch code."
}

# Set compiling directory
REPO='lokahost/lokahost'
BUILD_DIR='/tmp/lokahost-src'
INSTALL_DIR='/usr/local/lokahost'
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_DIR="$SRC_DIR/src/archive/"
architecture="$(arch)"
if [ $architecture == 'aarch64' ]; then
	BUILD_ARCH='arm64'
else
	BUILD_ARCH='amd64'
fi
RPM_DIR="$BUILD_DIR/rpm/"
DEB_DIR="$BUILD_DIR/deb"
if [ -f '/etc/redhat-release' ]; then
	BUILD_RPM=true
	BUILD_DEB=false
	OSTYPE='rhel'
else
	BUILD_RPM=false
	BUILD_DEB=true
	OSTYPE='debian'
fi

# Set packages to compile
for i in $*; do
	case "$i" in
		--all)
			NGINX_B='true'
			PHP_B='true'
			WEB_TERMINAL_B='true'
			LOKAHOST_B='true'
			;;
		--nginx)
			NGINX_B='true'
			;;
		--php)
			PHP_B='true'
			;;
		--web-terminal)
			WEB_TERMINAL_B='true'
			;;
		--lokahost)
			LOKAHOST_B='true'
			;;
		--debug)
			LOKAHOST_DEBUG='true'
			;;
		--install | Y)
			install='true'
			;;
		--noinstall | N)
			install='false'
			;;
		--keepbuild)
			KEEPBUILD='true'
			;;
		--cross)
			CROSS='true'
			;;
		--help | -h)
			usage
			exit 1
			;;
		--dontinstalldeps)
			dontinstalldeps='true'
			;;
		*)
			branch="$i"
			;;
	esac
done

if [[ $# -eq 0 ]]; then
	usage
	exit 1
fi

# Clear previous screen output
clear

# Set command variables
if [ -z $branch ]; then
	echo -n "Please enter the name of the branch to build from (e.g. main): "
	read branch
fi

if [ $(echo "$branch" | grep '^~localsrc') ]; then
	branch=$(echo "$branch" | sed 's/^~//')
	use_src_folder='true'
else
	use_src_folder='false'
fi

if [ -z $install ]; then
	echo -n 'Would you like to install the compiled packages? [y/N] '
	read install
fi

# Set Version for compiling
if [ -f "$SRC_DIR/src/deb/lokahost/control" ] && [ "$use_src_folder" == 'true' ]; then
	BUILD_VER=$(cat $SRC_DIR/src/deb/lokahost/control | grep "Version:" | cut -d' ' -f2)
	NGINX_V=$(cat $SRC_DIR/src/deb/nginx/control | grep "Version:" | cut -d' ' -f2)
	PHP_V=$(cat $SRC_DIR/src/deb/php/control | grep "Version:" | cut -d' ' -f2)
	WEB_TERMINAL_V=$(cat $SRC_DIR/src/deb/web-terminal/control | grep "Version:" | cut -d' ' -f2)
else
	BUILD_VER=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/lokahost/control | grep "Version:" | cut -d' ' -f2)
	NGINX_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/nginx/control | grep "Version:" | cut -d' ' -f2)
	PHP_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/php/control | grep "Version:" | cut -d' ' -f2)
	WEB_TERMINAL_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/web-terminal/control | grep "Version:" | cut -d' ' -f2)
fi

if [ -z "$BUILD_VER" ]; then
	echo "Error: Branch invalid, could not detect version"
	exit 1
fi

echo "Build version $BUILD_VER, with Nginx version $NGINX_V, PHP version $PHP_V and Web Terminal version $WEB_TERMINAL_V"

if [ -e "/etc/redhat-release" ]; then
	LOKAHOST_V="${BUILD_VER}"
else
	LOKAHOST_V="${BUILD_VER}_${BUILD_ARCH}"
fi
OPENSSL_V='3.1.2'
PCRE_V='10.42'
ZLIB_V='1.3'

# Create build directories
if [ "$KEEPBUILD" != 'true' ]; then
	rm -rf $BUILD_DIR
fi
mkdir -p $BUILD_DIR
mkdir -p $DEB_DIR
mkdir -p $RPM_DIR
mkdir -p $ARCHIVE_DIR

# Define a timestamp function
timestamp() {
	date +%s
}

if [ "$dontinstalldeps" != 'true' ]; then
	# Install needed software
	if [ "$OSTYPE" = 'rhel' ]; then
		# Set package dependencies for compiling
		SOFTWARE='wget tar git curl mock rpm-build rpmdevtools'

		echo "Updating system DNF repositories..."
		dnf install -y -q 'dnf-command(config-manager)'
		dnf install -y -q dnf-plugins-core epel-release
		dnf config-manager --set-enabled powertools > /dev/null 2>&1
		dnf config-manager --set-enabled PowerTools > /dev/null 2>&1
		dnf config-manager --set-enabled crb > /dev/null 2>&1
		dnf upgrade -y -q
		echo "Installing dependencies for compilation..."
		dnf install -y -q $SOFTWARE
		rpmdev-setuptree
		if [ ! -d "/var/lib/mock/rocky+epel-9-$(arch)-bootstrap" ]; then
			mock -r rocky+epel-9-$(arch) --init
		fi
	else
		# Set package dependencies for compiling
		SOFTWARE='wget tar git curl build-essential libxml2-dev libz-dev libzip-dev libgmp-dev libcurl4-gnutls-dev unzip openssl libssl-dev pkg-config libsqlite3-dev libonig-dev rpm lsb-release'

		echo "Updating system APT repositories..."
		apt-get -qq update > /dev/null 2>&1
		echo "Installing dependencies for compilation..."
		apt-get -qq install -y $SOFTWARE > /dev/null 2>&1

		# Installing Node.js 20.x repo
		apt="/etc/apt/sources.list.d"
		codename="$(lsb_release -s -c)"

		if [ -z $(which "node") ]; then
			echo "Adding Node.js 20.x repo..."
			echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x $codename main" > $apt/nodesource.list
			echo "deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x $codename main" >> $apt/nodesource.list
			curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg > /dev/null 2>&1
		fi

		echo "Installing Node.js..."
		apt-get -qq update > /dev/null 2>&1
		apt -qq install -y nodejs > /dev/null 2>&1

		nodejs_version=$(/usr/bin/node -v | cut -f1 -d'.' | sed 's/v//g')

		if [ "$nodejs_version" -lt 18 ]; then
			echo "Requires Node.js 18.x or higher"
			exit 1
		fi

		# Fix for Debian PHP environment
		if [ $BUILD_ARCH == "amd64" ]; then
			if [ ! -L /usr/local/include/curl ]; then
				ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl
			fi
		fi
	fi
fi

# Get system cpu cores
NUM_CPUS=$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print $4}')

if [ "$LOKAHOST_DEBUG" ]; then
	if [ "$OSTYPE" = 'rhel' ]; then
		echo "OS type          : RHEL / Rocky Linux / AlmaLinux / EuroLinux"
	else
		echo "OS type          : Debian / Ubuntu"
	fi
	echo "Branch           : $branch"
	echo "Install          : $install"
	echo "Build RPM        : $BUILD_RPM"
	echo "Build DEB        : $BUILD_DEB"
	echo "Lokahost version   : $BUILD_VER"
	echo "Nginx version    : $NGINX_V"
	echo "PHP version      : $PHP_V"
	echo "Web Term version : $WEB_TERMINAL_V"
	echo "Architecture     : $BUILD_ARCH"
	echo "Debug mode       : $LOKAHOST_DEBUG"
	echo "Source directory : $SRC_DIR"
fi

# Generate Links for sourcecode
LOKAHOST_ARCHIVE_LINK='https://github.com/lokahost/lokahost/archive/'$branch'.tar.gz'
if [[ $NGINX_V =~ - ]]; then
	NGINX='https://nginx.org/download/nginx-'$(echo $NGINX_V | cut -d"-" -f1)'.tar.gz'
else
	NGINX='https://nginx.org/download/nginx-'$(echo $NGINX_V | cut -d"~" -f1)'.tar.gz'
fi

OPENSSL='https://www.openssl.org/source/openssl-'$OPENSSL_V'.tar.gz'
PCRE='https://github.com/PCRE2Project/pcre2/releases/download/pcre2-'$PCRE_V'/pcre2-'$PCRE_V'.tar.gz'
ZLIB='https://github.com/madler/zlib/archive/refs/tags/v'$ZLIB_V'.tar.gz'

if [[ $PHP_V =~ - ]]; then
	PHP='http://de2.php.net/distributions/php-'$(echo $PHP_V | cut -d"-" -f1)'.tar.gz'
else
	PHP='http://de2.php.net/distributions/php-'$(echo $PHP_V | cut -d"~" -f1)'.tar.gz'
fi

# Forward slashes in branchname are replaced with dashes to match foldername in github archive.
branch_dash=$(echo "$branch" | sed 's/\//-/g')

#################################################################################
#
# Building lokahost-nginx
#
#################################################################################

if [ "$NGINX_B" = true ]; then
	echo "Building lokahost-nginx package..."
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for lokahost-nginx, lokahost-php or lokahost-web-terminal"
		exit 1
	fi

	if [ "$BUILD_DEB" = true ]; then
		# Change to build directory
		cd $BUILD_DIR

		BUILD_DIR_LOKAHOSTNGINX=$BUILD_DIR/lokahost-nginx_$NGINX_V
		if [[ $NGINX_V =~ - ]]; then
			BUILD_DIR_NGINX=$BUILD_DIR/nginx-$(echo $NGINX_V | cut -d"-" -f1)
		else
			BUILD_DIR_NGINX=$BUILD_DIR/nginx-$(echo $NGINX_V | cut -d"~" -f1)
		fi

		if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_LOKAHOSTNGINX" ]; then
			# Check if target directory exist
			if [ -d "$BUILD_DIR_LOKAHOSTNGINX" ]; then
				#mv $BUILD_DIR/lokahost-nginx_$NGINX_V $BUILD_DIR/lokahost-nginx_$NGINX_V-$(timestamp)
				rm -r "$BUILD_DIR_LOKAHOSTNGINX"
			fi

			# Create directory
			mkdir -p $BUILD_DIR_LOKAHOSTNGINX

			# Download and unpack source files
			download_file $NGINX '-' | tar xz
			download_file $OPENSSL '-' | tar xz
			download_file $PCRE '-' | tar xz
			download_file $ZLIB '-' | tar xz

			# Change to nginx directory
			cd $BUILD_DIR_NGINX

			# configure nginx
			./configure --prefix=/usr/local/lokahost/nginx \
				--with-http_v2_module \
				--with-http_ssl_module \
				--with-openssl=../openssl-$OPENSSL_V \
				--with-openssl-opt=enable-ec_nistp_64_gcc_128 \
				--with-openssl-opt=no-nextprotoneg \
				--with-openssl-opt=no-weak-ssl-ciphers \
				--with-openssl-opt=no-ssl3 \
				--with-pcre=../pcre2-$PCRE_V \
				--with-pcre-jit \
				--with-zlib=../zlib-$ZLIB_V
		fi

		# Change to nginx directory
		cd $BUILD_DIR_NGINX

		# Check install directory and remove if exists
		if [ -d "$BUILD_DIR$INSTALL_DIR" ]; then
			rm -r "$BUILD_DIR$INSTALL_DIR"
		fi

		# Copy local lokahost source files
		if [ "$use_src_folder" == 'true' ] && [ -d $SRC_DIR ]; then
			cp -rf "$SRC_DIR/" $BUILD_DIR/lokahost-$branch_dash
		fi

		# Create the files and install them
		make -j $NUM_CPUS && make DESTDIR=$BUILD_DIR install

		# Clear up unused files
		if [ "$KEEPBUILD" != 'true' ]; then
			rm -r $BUILD_DIR_NGINX $BUILD_DIR/openssl-$OPENSSL_V $BUILD_DIR/pcre2-$PCRE_V $BUILD_DIR/zlib-$ZLIB_V
		fi
		cd $BUILD_DIR_LOKAHOSTNGINX

		# Move nginx directory
		mkdir -p $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost
		rm -rf $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost/nginx
		mv $BUILD_DIR/usr/local/lokahost/nginx $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost/

		# Remove original nginx.conf (will use custom)
		rm -f $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost/nginx/conf/nginx.conf

		# copy binary
		mv $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost/nginx/sbin/nginx $BUILD_DIR_LOKAHOSTNGINX/usr/local/lokahost/nginx/sbin/lokahost-nginx

		# change permission and build the package
		cd $BUILD_DIR
		chown -R root:root $BUILD_DIR_LOKAHOSTNGINX
		# Get Debian package files
		mkdir -p $BUILD_DIR_LOKAHOSTNGINX/DEBIAN
		get_branch_file 'src/deb/nginx/control' "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/control"
		if [ "$BUILD_ARCH" != "amd64" ]; then
			sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/control"
		fi
		get_branch_file 'src/deb/nginx/copyright' "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/copyright"
		get_branch_file 'src/deb/nginx/postinst' "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/postinst"
		get_branch_file 'src/deb/nginx/postrm' "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/portrm"
		chmod +x "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/postinst"
		chmod +x "$BUILD_DIR_LOKAHOSTNGINX/DEBIAN/portrm"

		# Init file
		mkdir -p $BUILD_DIR_LOKAHOSTNGINX/etc/init.d
		get_branch_file 'src/deb/nginx/lokahost' "$BUILD_DIR_LOKAHOSTNGINX/etc/init.d/lokahost"
		chmod +x "$BUILD_DIR_LOKAHOSTNGINX/etc/init.d/lokahost"

		# Custom config
		get_branch_file 'src/deb/nginx/nginx.conf' "${BUILD_DIR_LOKAHOSTNGINX}/usr/local/lokahost/nginx/conf/nginx.conf"

		# Build the package
		echo Building Nginx DEB
		dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOSTNGINX $DEB_DIR

		rm -r $BUILD_DIR/usr

		if [ "$KEEPBUILD" != 'true' ]; then
			# Clean up the source folder
			rm -r lokahost- nginx_$NGINX_V
			rm -rf $BUILD_DIR/rpmbuild
			if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/lokahost-$branch_dash ]; then
				rm -r $BUILD_DIR/lokahost-$branch_dash
			fi
		fi
	fi

	if [ "$BUILD_RPM" = true ]; then
		# Get RHEL package files
		get_branch_file 'src/rpm/nginx/nginx.conf' "$HOME/rpmbuild/SOURCES/nginx.conf"
		get_branch_file 'src/rpm/nginx/lokahost-nginx.spec' "$HOME/rpmbuild/SPECS/lokahost-nginx.spec"
		get_branch_file 'src/rpm/nginx/lokahost-nginx.service' "$HOME/rpmbuild/SOURCES/lokahost-nginx.service"

		# Download source files
		download_file $NGINX "$HOME/rpmbuild/SOURCES/"

		# Build the package
		echo Building Nginx RPM
		rpmbuild -bs ~/rpmbuild/SPECS/lokahost-nginx.spec
		mock -r rocky+epel-9-$(arch) ~/rpmbuild/SRPMS/lokahost-nginx-$NGINX_V-1.el9.src.rpm
		cp /var/lib/mock/rocky+epel-9-$(arch)/result/*.rpm $RPM_DIR
		rm -rf ~/rpmbuild/SPECS/* ~/rpmbuild/SOURCES/* ~/rpmbuild/SRPMS/*
	fi
fi

#################################################################################
#
# Building lokahost-php
#
#################################################################################

if [ "$PHP_B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for lokahost-nginx, lokahost-php or lokahost-web-terminal"
		exit 1
	fi

	echo "Building lokahost-php package..."

	if [ "$BUILD_DEB" = true ]; then
		BUILD_DIR_LOKAHOSTPHP=$BUILD_DIR/lokahost-php_$PHP_V

		BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)

		if [[ $PHP_V =~ - ]]; then
			BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"-" -f1)
		else
			BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)
		fi

		if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_LOKAHOSTPHP" ]; then
			# Check if target directory exist
			if [ -d $BUILD_DIR_LOKAHOSTPHP ]; then
				rm -r $BUILD_DIR_LOKAHOSTPHP
			fi

			# Create directory
			mkdir -p $BUILD_DIR_LOKAHOSTPHP

			# Download and unpack source files
			cd $BUILD_DIR
			download_file $PHP '-' | tar xz

			# Change to untarred php directory
			cd $BUILD_DIR_PHP

			# Configure PHP
			./configure --prefix=/usr/local/lokahost/php \
				--with-libdir=lib/$(arch)-linux-gnu \
				--enable-fpm --with-fpm-user=admin --with-fpm-group=admin \
				--with-openssl \
				--with-mysqli \
				--with-gettext \
				--with-curl \
				--with-zip \
				--with-gmp \
				--enable-mbstring
		fi

		cd $BUILD_DIR_PHP

		# Create the files and install them
		make -j $NUM_CPUS && make INSTALL_ROOT=$BUILD_DIR install

		# Copy local lokahost source files
		if [ "$use_src_folder" == 'true' ] && [ -d $SRC_DIR ]; then
			[ "$LOKAHOST_DEBUG" ] && echo DEBUG: cp -rf "$SRC_DIR/" $BUILD_DIR/lokahost-$branch_dash
			cp -rf "$SRC_DIR/" $BUILD_DIR/lokahost-$branch_dash
		fi
		# Move php directory
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost
		mkdir -p $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost

		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: rm -r $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php
		if [ -d $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php ]; then
			rm -r $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php
		fi

		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mv ${BUILD_DIR}/usr/local/lokahost/php ${BUILD_DIR_LOKAHOSTPHP}/usr/local/lokahost/
		mv ${BUILD_DIR}/usr/local/lokahost/php ${BUILD_DIR_LOKAHOSTPHP}/usr/local/lokahost/

		# copy binary
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: cp $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php/sbin/php-fpm $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php/sbin/lokahost-php
		cp $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php/sbin/php-fpm $BUILD_DIR_LOKAHOSTPHP/usr/local/lokahost/php/sbin/lokahost-php

		# Change permissions and build the package
		chown -R root:root $BUILD_DIR_LOKAHOSTPHP
		# Get Debian package files
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_LOKAHOSTPHP/DEBIAN
		mkdir -p $BUILD_DIR_LOKAHOSTPHP/DEBIAN
		get_branch_file 'src/deb/php/control' "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/control"
		if [ "$BUILD_ARCH" != "amd64" ]; then
			sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/control"
		fi

		os=$(lsb_release -is)
		release=$(lsb_release -rs)
		if [[ "$os" = "Ubuntu" ]] && [[ "$release" = "20.04" ]]; then
			sed -i "/Conflicts: libzip5/d" "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/control"
			sed -i "s/libzip4/libzip5/g" "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/control"
		fi

		get_branch_file 'src/deb/php/copyright' "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/copyright"
		get_branch_file 'src/deb/php/postinst' "$BUILD_DIR_LOKAHOSTPHP/DEBIAN/postinst"
		chmod +x $BUILD_DIR_LOKAHOSTPHP/DEBIAN/postinst
		# Get custom config
		get_branch_file 'src/deb/php/php-fpm.conf' "${BUILD_DIR_LOKAHOSTPHP}/usr/local/lokahost/php/etc/php-fpm.conf"
		get_branch_file 'src/deb/php/php.ini' "${BUILD_DIR_LOKAHOSTPHP}/usr/local/lokahost/php/lib/php.ini"

		# Build the package
		echo Building PHP DEB
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOSTPHP $DEB_DIR
		dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOSTPHP $DEB_DIR

		rm -r $BUILD_DIR/usr

		# clear up the source folder
		if [ "$KEEPBUILD" != 'true' ]; then
			rm -r $BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)
			rm -r $BUILD_DIR_LOKAHOSTPHP
			if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/lokahost-$branch_dash ]; then
				rm -r $BUILD_DIR/lokahost-$branch_dash
			fi
		fi
	fi

	if [ "$BUILD_RPM" = true ]; then
		# Get RHEL package files
		get_branch_file 'src/rpm/php/php-fpm.conf' "$HOME/rpmbuild/SOURCES/php-fpm.conf"
		get_branch_file 'src/rpm/php/php.ini' "$HOME/rpmbuild/SOURCES/php.ini"
		get_branch_file 'src/rpm/php/lokahost-php.spec' "$HOME/rpmbuild/SPECS/lokahost-php.spec"
		get_branch_file 'src/rpm/php/lokahost-php.service' "$HOME/rpmbuild/SOURCES/lokahost-php.service"

		# Download source files
		download_file $PHP "$HOME/rpmbuild/SOURCES/"

		# Build RPM package
		echo Building PHP RPM
		rpmbuild -bs ~/rpmbuild/SPECS/lokahost-php.spec
		mock -r rocky+epel-9-$(arch) ~/rpmbuild/SRPMS/lokahost-php-$PHP_V-1.el9.src.rpm
		cp /var/lib/mock/rocky+epel-9-$(arch)/result/*.rpm $RPM_DIR
		rm -rf ~/rpmbuild/SPECS/* ~/rpmbuild/SOURCES/* ~/rpmbuild/SRPMS/*
	fi
fi

#################################################################################
#
# Building lokahost-web-terminal
#
#################################################################################

if [ "$WEB_TERMINAL_B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for lokahost-nginx, lokahost-php or lokahost-web-terminal"
		exit 1
	fi

	echo "Building lokahost-web-terminal package..."

	if [ "$BUILD_DEB" = true ]; then
		BUILD_DIR_LOKAHOST_TERMINAL=$BUILD_DIR/lokahost-web-terminal_$WEB_TERMINAL_V

		# Check if target directory exist
		if [ -d $BUILD_DIR_LOKAHOST_TERMINAL ]; then
			rm -r $BUILD_DIR_LOKAHOST_TERMINAL
		fi

		# Create directory
		mkdir -p $BUILD_DIR_LOKAHOST_TERMINAL
		chown -R root:root $BUILD_DIR_LOKAHOST_TERMINAL

		# Get Debian package files
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN
		mkdir -p $BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN
		get_branch_file 'src/deb/web-terminal/control' "$BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN/control"
		if [ "$BUILD_ARCH" != "amd64" ]; then
			sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN/control"
		fi

		get_branch_file 'src/deb/web-terminal/copyright' "$BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN/copyright"
		get_branch_file 'src/deb/web-terminal/postinst' "$BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN/postinst"
		chmod +x $BUILD_DIR_LOKAHOST_TERMINAL/DEBIAN/postinst

		# Get server files
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mkdir -p "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal"
		mkdir -p "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal"
		get_branch_file 'src/deb/web-terminal/package.json' "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal/package.json"
		get_branch_file 'src/deb/web-terminal/package-lock.json' "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal/package-lock.json"
		get_branch_file 'src/deb/web-terminal/server.js' "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal/server.js"
		chmod +x "${BUILD_DIR_LOKAHOST_TERMINAL}/usr/local/lokahost/web-terminal/server.js"

		cd $BUILD_DIR_LOKAHOST_TERMINAL/usr/local/lokahost/web-terminal
		npm ci --omit=dev

		# Systemd service
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_LOKAHOST_TERMINAL/etc/systemd/system
		mkdir -p $BUILD_DIR_LOKAHOST_TERMINAL/etc/systemd/system
		get_branch_file 'src/deb/web-terminal/lokahost-web-terminal.service' "$BUILD_DIR_LOKAHOST_TERMINAL/etc/systemd/system/lokahost-web-terminal.service"

		# Build the package
		echo Building Web Terminal DEB
		[ "$LOKAHOST_DEBUG" ] && echo DEBUG: dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOST_TERMINAL $DEB_DIR
		dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOST_TERMINAL $DEB_DIR

		# clear up the source folder
		if [ "$KEEPBUILD" != 'true' ]; then
			rm -r $BUILD_DIR_LOKAHOST_TERMINAL
			if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/lokahost-$branch_dash ]; then
				rm -r $BUILD_DIR/lokahost-$branch_dash
			fi
		fi
	fi
fi

#################################################################################
#
# Building lokahost
#
#################################################################################

arch="$BUILD_ARCH"

if [ "$LOKAHOST_B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		arch="amd64 arm64"
	fi
	for BUILD_ARCH in $arch; do
		echo "Building Lokahost Control Panel package..."

		if [ "$BUILD_DEB" = true ]; then
			BUILD_DIR_LOKAHOST=$BUILD_DIR/lokahost_$LOKAHOST_V

			# Change to build directory
			cd $BUILD_DIR

			if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_LOKAHOST" ]; then
				# Check if target directory exist
				if [ -d $BUILD_DIR_LOKAHOST ]; then
					rm -r $BUILD_DIR_LOKAHOST
				fi

				# Create directory
				mkdir -p $BUILD_DIR_LOKAHOST
			fi

			cd $BUILD_DIR
			rm -rf $BUILD_DIR/lokahost-$branch_dash
			# Download and unpack source files
			if [ "$use_src_folder" == 'true' ]; then
				[ "$LOKAHOST_DEBUG" ] && echo DEBUG: cp -rf "$SRC_DIR/" $BUILD_DIR/lokahost-$branch_dash
				cp -rf "$SRC_DIR/" $BUILD_DIR/lokahost-$branch_dash
			elif [ -d $SRC_DIR ]; then
				download_file $LOKAHOST_ARCHIVE_LINK '-' 'fresh' | tar xz
			fi

			mkdir -p $BUILD_DIR_LOKAHOST/usr/local/lokahost

			# Build web and move needed directories
			cd $BUILD_DIR/lokahost-$branch_dash
			npm ci --ignore-scripts
			npm run build
			cp -rf bin func install web $BUILD_DIR_LOKAHOST/usr/local/lokahost/

			# Set permissions
			find $BUILD_DIR_LOKAHOST/usr/local/lokahost/ -type f -exec chmod -x {} \;

			# Allow send email via /usr/local/lokahost/web/inc/mail-wrapper.php via cli
			chmod +x $BUILD_DIR_LOKAHOST/usr/local/lokahost/web/inc/mail-wrapper.php
			# Allow the executable to be executed
			chmod +x $BUILD_DIR_LOKAHOST/usr/local/lokahost/bin/*
			find $BUILD_DIR_LOKAHOST/usr/local/lokahost/install/ \( -name '*.sh' \) -exec chmod +x {} \;
			chmod -x $BUILD_DIR_LOKAHOST/usr/local/lokahost/install/*.sh
			chown -R root:root $BUILD_DIR_LOKAHOST
			# Get Debian package files
			mkdir -p $BUILD_DIR_LOKAHOST/DEBIAN
			get_branch_file 'src/deb/lokahost/control' "$BUILD_DIR_LOKAHOST/DEBIAN/control"
			if [ "$BUILD_ARCH" != "amd64" ]; then
				sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_LOKAHOST/DEBIAN/control"
			fi
			get_branch_file 'src/deb/lokahost/copyright' "$BUILD_DIR_LOKAHOST/DEBIAN/copyright"
			get_branch_file 'src/deb/lokahost/preinst' "$BUILD_DIR_LOKAHOST/DEBIAN/preinst"
			get_branch_file 'src/deb/lokahost/postinst' "$BUILD_DIR_LOKAHOST/DEBIAN/postinst"
			chmod +x $BUILD_DIR_LOKAHOST/DEBIAN/postinst
			chmod +x $BUILD_DIR_LOKAHOST/DEBIAN/preinst

			echo Building Lokahost DEB
			dpkg-deb -Zxz --build $BUILD_DIR_LOKAHOST $DEB_DIR

			# clear up the source folder
			if [ "$KEEPBUILD" != 'true' ]; then
				rm -r $BUILD_DIR_LOKAHOST
				rm -rf lokahost-$branch_dash
			fi
			cd $BUILD_DIR/lokahost-$branch_dash
		fi

		if [ "$BUILD_RPM" = true ]; then
			# Pre-clean
			rm -rf ~/rpmbuild/SOURCES/*

			# Get RHEL package files
			get_branch_file 'src/rpm/lokahost/lokahost.spec' "$HOME/rpmbuild/SPECS/lokahost.spec"
			get_branch_file 'src/rpm/lokahost/lokahost.service' "$HOME/rpmbuild/SOURCES/lokahost.service"

			# Generate source tar.gz
			tar -czf $HOME/rpmbuild/SOURCES/lokahost-$BUILD_VER.tar.gz -C $SRC_DIR/.. lokahost

			# Build RPM package
			echo Building Lokahost RPM
			rpmbuild -bs ~/rpmbuild/SPECS/lokahost.spec
			mock -r rocky+epel-9-$(arch) ~/rpmbuild/SRPMS/lokahost-$BUILD_VER-1.el9.src.rpm
			cp /var/lib/mock/rocky+epel-9-$(arch)/result/*.rpm $RPM_DIR
			rm -rf ~/rpmbuild/SPECS/* ~/rpmbuild/SOURCES/* ~/rpmbuild/SRPMS/*
		fi

	done
fi

#################################################################################
#
# Install Packages
#
#################################################################################

if [ "$install" = 'yes' ] || [ "$install" = 'y' ] || [ "$install" = 'true' ]; then
	# Install all available packages
	echo "Installing packages..."
	if [ "$OSTYPE" = 'rhel' ]; then
		for i in $RPM_DIR/*.rpm; do
			dnf -y install $i
			if [ $? -ne 0 ]; then
				exit 1
			fi
		done
	else
		for i in $DEB_DIR/*.deb; do
			dpkg -i $i
			if [ $? -ne 0 ]; then
				exit 1
			fi
		done
	fi
	unset $answer
fi
