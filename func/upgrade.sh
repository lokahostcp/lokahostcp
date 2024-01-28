#!/bin/bash

#===========================================================================#
#                                                                           #
# Lokahost Control Panel - Upgrade Function Library                           #
#                                                                           #
#===========================================================================#

# Import system health check and repair library
# shellcheck source=/usr/local/lokahost/func/syshealth.sh
source $LOKAHOST/func/syshealth.sh

#####################################################################
#######                Functions & Initialization             #######
#####################################################################

add_upgrade_message() {
	if [ -f "$LOKAHOST_BACKUP/message.log" ]; then
		echo -e $1 >> $LOKAHOST_BACKUP/message.log
		echo -e "\n\n" >> $LOKAHOST_BACKUP/message.log
	else
		echo -e $1 > $LOKAHOST_BACKUP/message.log
	fi
}

is_debug_build() {
	if [[ "$new_version" =~ "alpha" ]] || [[ "$new_version" =~ "beta" ]]; then
		DEBUG_MODE="true"
	fi

	# Remove pre-release designation tags from display version
	DISPLAY_VER=$(echo $new_version | sed "s|~alpha||g" | sed "s|~beta||g")
}

upgrade_health_check() {

	echo "============================================================================="
	echo "[ ! ] Performing system health check before proceeding with installation...  "
	# Perform basic health check against lokahost.conf to ensure that
	# system variables exist and are set to expected defaults.

	if [ -z "$VERSION" ]; then
		export VERSION="1.1.0"
		$BIN/v-change-sys-config-value 'VERSION' "$VERSION"
		echo
		echo "[ ! ] Unable to detect installed version of Lokahost Control Panel."
		echo "      Setting default version to $VERSION and processing upgrade steps."
		echo
	fi

	syshealth_repair_system_config

	echo "[ * ] Health check complete. Starting upgrade from $VERSION to $new_version..."
	echo "============================================================================="
}

upgrade_welcome_message() {
	echo
	echo '                  _   _           _   _        ____ ____                      '
	echo '                 | | | | ___  ___| |_(_) __ _ / ___|  _ \                     '
	echo '                 | |_| |/ _ \/ __| __| |/ _` | |   | |_) |                    '
	echo '                 |  _  |  __/\__ \ |_| | (_| | |___|  __/                     '
	echo '                 |_| |_|\___||___/\__|_|\__,_|\____|_|                        '
	echo "                                                                              "
	echo "                    Lokahost Control Panel Software Update                      "
	echo "                               Version: ${DISPLAY_VER}"
	if [[ "$new_version" =~ "beta" ]]; then
		echo "                                BETA RELEASE                                 "
	fi
	if [[ "$new_version" =~ "alpha" ]]; then
		echo "                            DEVELOPMENT SNAPSHOT                             "
		echo "                      NOT INTENDED FOR PRODUCTION USE                        "
		echo "                            USE AT YOUR OWN RISK                             "
	fi
	echo
	echo "============================================================================="
	echo
	echo "[ ! ] IMPORTANT INFORMATION:                                                 "
	echo
	echo "Default configuration files and templates may be modified or replaced        "
	echo "during the upgrade process. You may restore these files from:                "
	echo ""
	echo "Backup directory: $LOKAHOST_BACKUP/"
	echo "Installation log: $LOG"
}

upgrade_welcome_message_log() {
	echo "============================================================================="
	echo "Lokahost Control Panel Software Update Log"
	echo "============================================================================="
	echo
	echo "OPERATING SYSTEM:      $OS_TYPE ($OS_VERSION)"
	echo "CURRENT VERSION:       $VERSION"
	echo "NEW VERSION:           $new_version"
	echo "RELEASE BRANCH:        $RELEASE_BRANCH"
	if [[ "$new_version" =~ "alpha" ]]; then
		echo "BUILD TYPE:            Development snapshot"
	elif [[ "$new_version" =~ "beta" ]]; then
		echo "BUILD TYPE:            Beta release"
	else
		echo "BUILD TYPE:            Production release"
	fi
	echo
	echo "INSTALLER OPTIONS:"
	echo "============================================================================="
	echo "Send email notification on upgrade complete:      $UPGRADE_SEND_EMAIL"
	echo "Send installed log output to admin email:         $UPGRADE_SEND_EMAIL_LOG"
	echo
}

upgrade_step_message() {
	echo
	echo "[ - ] Now applying patches and updates for version v$version_step..."
}

upgrade_complete_message() {
	# Echo message to console output
	echo "============================================================================="
	echo
	echo "Upgrade complete! If you encounter any issues or find a bug,                 "
	echo "please take a moment to report it to us on GitHub at the URL below:          "
	echo "https://github.com/lokahost/lokahost/issues                                  "
	echo
	echo "Read the release notes to learn about new fixes and features:                "
	echo "https://github.com/lokahost/lokahost/blob/release/CHANGELOG.md               "
	echo
	echo "We hope that you enjoy using this version of Lokahost Control Panel,           "
	echo "have a wonderful day!                                                        "
	echo
	echo "Sincerely,                                                                   "
	echo "The Lokahost Control Panel development team                                    "
	echo
	echo "Web:      https://www.lokahost.com/                                          "
	echo "Docs:     https://docs.lokahost.com/										   "
	echo "Forum:    https://forum.lokahost.com/                                        "
	echo "GitHub:   https://github.com/lokahost/lokahost/                              "
	echo
	echo "Help support the Lokahost Control Panel project by donating via PayPal:        "
	echo "https://www.lokahost.com/donate                                              "
	echo
	echo "Made with love & pride by the open-source community around the world.        "
	echo
	echo "============================================================================="
	echo
}

upgrade_complete_message_log() {
	echo
	echo "============================================================================="
	echo "UPGRADE COMPLETE.                                                            "
	echo "Please report any issues on GitHub:                                          "
	echo "https://github.com/lokahost/lokahost/issues                                  "
	echo "============================================================================="
	echo
	$BIN/v-log-action "system" "Info" "Updates" "Update installed (Version: $new_version)."
}

upgrade_cleanup_message() {
	echo "============================================================================="
	echo "Installation tasks complete, performing clean-up...                          "
	echo "============================================================================="
}

upgrade_get_version() {
	# Retrieve new version number for Lokahost Control Panel from .deb package
	new_version=$(dpkg -l | awk '$2=="lokahost" { print $3 }')
}

upgrade_set_version() {
	# Set new version number in lokahost.conf
	$BIN/v-change-sys-config-value "VERSION" "$@"
}

upgrade_set_branch() {
	# Set branch in lokahost.conf
	DISPLAY_VER=$(echo "$1" | sed "s|~alpha||g" | sed "s|~beta||g")
	if [ "$DISPLAY_VER" = "$1" ]; then
		$BIN/v-change-sys-config-value "RELEASE_BRANCH" "release"
	fi
}

upgrade_send_notification_to_panel() {
	# If ROOT_USER is not set fallback to admin
	if [ -z "$ROOT_USER" ]; then
		ROOT_USER="admin"
	fi
	# Add notification to panel if variable is set to true or is not set
	if [[ "$new_version" =~ "alpha" ]]; then
		# Send notifications for development releases
		$BIN/v-add-user-notification "$ROOT_USER" 'Development snapshot installed' '<p><span class="u-text-bold">Version:</span> '$new_version'<br><span class="u-text-bold">Code Branch:</span> '$RELEASE_BRANCH'</p><p>Please report any bugs by <a href="https://github.com/lokahost/lokahost/issues" target="_blank">opening an issue on GitHub</a>, and feel free to share your feedback on our <a href="https://forum.lokahost.com" target="_blank">discussion forum</a>.</p><p><i class="fas fa-heart icon-red"></i> The Lokahost Control Panel development team</p>'
	elif [[ "$new_version" =~ "beta" ]]; then
		# Send feedback notification for beta releases
		$BIN/v-add-user-notification "$ROOT_USER" 'Thank you for testing Lokahost Control Panel '$new_version'.' '<p>Please share your feedback with our development team through our <a href="https://forum.lokahost.com" target="_blank">discussion forum</a>.</p><p>Found a bug? <a href="https://github.com/lokahost/lokahost/issues" target="_blank">Open an issue on GitHub</a>!</p><p><i class="fas fa-heart icon-red"></i> The Lokahost Control Panel development team</p>'
	else
		# Send normal upgrade complete notification for stable releases
		$BIN/v-add-user-notification "$ROOT_USER" 'Upgrade complete' '<p>Lokahost Control Panel has been updated to <span class="u-text-bold">v'$new_version'</span>.</p><p><a href="https://github.com/lokahost/lokahost/blob/release/CHANGELOG.md" target="_blank">View release notes</a></p><p>Please report any bugs by <a href="https://github.com/lokahost/lokahost/issues" target="_blank">opening an issue on GitHub</a>.</p><p class="u-text-bold">Have a wonderful day!</p><p><i class="fas fa-heart icon-red"></i> The Lokahost Control Panel development team</p>'
	fi
}

upgrade_send_notification_to_email() {
	# If ROOT_USER is not set fallback to admin
	if [ -z "$ROOT_USER" ]; then
		ROOT_USER="admin"
	fi
	if [ "$UPGRADE_SEND_EMAIL" = "true" ]; then
		# Retrieve admin email address, sendmail path, and message temp file path
		admin_email=$($BIN/v-list-user "$ROOT_USER" json | grep "CONTACT" | cut -d'"' -f4)
		send_mail="$LOKAHOST/web/inc/mail-wrapper.php"
		message_tmp_file="/tmp/lokahost-upgrade-complete.txt"

		# Create temporary file
		touch $message_tmp_file

		# Write message to file
		echo "$HOSTNAME has been upgraded from Lokahost Control Panel v$VERSION to v${new_version}." >> $message_tmp_file
		echo "Installation log: $LOG" >> $message_tmp_file
		echo "" >> $message_tmp_file

		# Check for additional upgrade notes from update scripts.
		if [[ -f "$LOKAHOST_BACKUP/message.log" ]]; then
			echo "===================================================" >> $message_tmp_file
			echo "The upgrade script has generated additional notifications, which must be heeded urgently:" >> $message_tmp_file
			echo "" >> $message_tmp_file
			cat $LOKAHOST_BACKUP/message.log >> $message_tmp_file
			echo "" >> $message_tmp_file
			echo "===================================================" >> $message_tmp_file
			echo "" >> $message_tmp_file
		fi

		echo "What's new: https://github.com/lokahost/lokahost/blob/$RELEASE_BRANCH/CHANGELOG.md" >> $message_tmp_file
		echo >> $message_tmp_file
		echo "What to do if you run into issues:" >> $message_tmp_file
		echo "- Check our forums for possible solutions: https://forum.lokahost.com" >> $message_tmp_file
		echo "- File an issue report on GitHub: https://github.com/lokahost/lokahost/issues" >> $message_tmp_file
		echo "" >> $message_tmp_file
		echo "Help support the Lokahost Control Panel project by donating via PayPal: https://www.lokahost.com/donate" >> $message_tmp_file
		echo "===================================================" >> $message_tmp_file
		echo "Have a wonderful day," >> $message_tmp_file
		echo "The Lokahost Control Panel development team" >> $message_tmp_file

		# Read back message from file and pass through to sendmail
		cat $message_tmp_file | $send_mail -s "Update Installed - v${new_version}" $admin_email
		rm -f $message_tmp_file
	fi
}

upgrade_send_log_to_email() {
	if [ "$UPGRADE_SEND_EMAIL_LOG" = "true" ]; then
		admin_email=$($BIN/v-list-user $ROOT_USER json | grep "CONTACT" | cut -d'"' -f4)
		send_mail="$LOKAHOST/web/inc/mail-wrapper.php"
		cat $LOG | $send_mail -s "Update Installation Log - v${new_version}" $admin_email
	fi
}

upgrade_config_set_value() {
	if [ -f "$LOKAHOST_BACKUP/upgrade.conf" ]; then
		if [ "$2" = "true" ]; then
			sed -i "s/$1='false'/$1='true'/g" $LOKAHOST_BACKUP/upgrade.conf
		fi
	fi
}

prepare_upgrade_config() {
	mkdir -p $LOKAHOST_BACKUP
	touch $LOKAHOST_BACKUP/upgrade.conf
	while IFS='= ' read -r lhs rhs; do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%\#*}"  # Del in line right comments
			rhs="${rhs%%*( )}" # Del trailing spaces
			rhs="${rhs%\'*}"   # Del opening string quotes
			rhs="${rhs#\'*}"   # Del closing string quotes
			echo "$lhs='$rhs'" >> $LOKAHOST_BACKUP/upgrade.conf
		fi
	done < "$LOKAHOST/install/upgrade/upgrade.conf"
}

upgrade_init_backup() {
	# Ensure that backup directories are created
	# Lokahost Control Panel configuration files
	mkdir -p $LOKAHOST_BACKUP/conf/lokahost/

	# OpenSSL configuration files
	mkdir -p $LOKAHOST_BACKUP/conf/openssl/

	# Hosting Packages
	mkdir -p $LOKAHOST_BACKUP/packages/

	# Domain template files
	mkdir -p $LOKAHOST_BACKUP/templates/

	# System services (apache2, nginx, bind9, vsftpd, etc).
	if [ -n "$WEB_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$WEB_SYSTEM/
	fi
	if [ -n "$IMAP_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$IMAP_SYSTEM/
	fi
	if [ -n "$MAIL_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$MAIL_SYSTEM/
	fi
	if [ -n "$DNS_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$DNS_SYSTEM/
	fi
	if [ -n "$PROXY_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$PROXY_SYSTEM/
	fi
	if [ -n "$DB_SYSTEM" ]; then
		if [[ "$DB_SYSTEM" =~ "mysql" ]]; then
			mkdir -p $LOKAHOST_BACKUP/conf/mysql/
		fi
		if [[ "$DB_SYSTEM" =~ "pgsql" ]]; then
			mkdir -p $LOKAHOST_BACKUP/conf/pgsql/
		fi
	fi
	if [ -n "$FTP_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$FTP_SYSTEM/
	fi
	if [ -n "$FIREWALL_SYSTEM" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$FIREWALL_SYSTEM/
	fi
	if [ -n "$FIREWALL_EXTENSION" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/$FIREWALL_EXTENSION/
	fi
	if [ -e "/etc/ssh/sshd_config" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/ssh/
	fi
	if [ -d "/etc/roundcube/" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/roundcube/
	fi
	if [ -d "/etc/snappymail/" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/snappymail/
	fi
	if [ -d "/etc/phpmyadmin/" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/phpmyadmin/
	fi
	if [ -d "/etc/phppgadmin/" ]; then
		mkdir -p $LOKAHOST_BACKUP/conf/phppgadmin/
	fi
}

upgrade_init_logging() {
	# Set log file path
	LOG="$LOKAHOST_BACKUP/lcp-upgrade-$(date +%d%m%Y%H%M).log"

	# Create log file
	touch $LOG

	# Add message to system log
	$BIN/v-log-action "system" "Info" "Updates" "Started update installation (Latest: $new_version, Previous: $VERSION)."

	# Add warnings for pre-release builds
	if [[ "$new_version" =~ "alpha" ]]; then
		$BIN/v-log-action "system" "Warning" "Updates" "Development build for testing purposes only. Report bugs at https://github.com/lokahost/lokahost/issues/."
	fi
	if [[ "$new_version" =~ "beta" ]]; then
		$BIN/v-log-action "system" "Warning" "Updates" "Beta release. Please report bugs at https://github.com/lokahost/lokahost/issues/."
	fi
}

upgrade_start_backup() {
	echo "============================================================================="
	echo "[ * ] Backing up existing templates and configuration files..."
	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      - Packages"
	fi
	cp -fr $LOKAHOST/data/packages/* $LOKAHOST_BACKUP/packages/

	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      - Templates"
	fi
	cp -fr $LOKAHOST/data/templates/* $LOKAHOST_BACKUP/templates/

	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      - Configuration files:"
	fi

	# Lokahost Control Panel configuration files
	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      ---- lokahost"
	fi
	cp -fr $LOKAHOST/conf/* $LOKAHOST_BACKUP/conf/lokahost/

	# OpenSSL configuration files
	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      ---- openssl"
	fi
	cp -f /etc/ssl/*.cnf $LOKAHOST_BACKUP/conf/openssl/

	# System service configuration files (apache2, nginx, bind9, vsftpd, etc).
	if [ -n "$WEB_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $WEB_SYSTEM"
		fi
		cp -fr /etc/$WEB_SYSTEM/* $LOKAHOST_BACKUP/conf/$WEB_SYSTEM/
	fi
	if [ -n "$PROXY_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $PROXY_SYSTEM"
		fi
		cp -fr /etc/$PROXY_SYSTEM/* $LOKAHOST_BACKUP/conf/$PROXY_SYSTEM/
	fi
	if [ -n "$IMAP_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $IMAP_SYSTEM"
		fi
		cp -fr /etc/$IMAP_SYSTEM/* $LOKAHOST_BACKUP/conf/$IMAP_SYSTEM/
	fi
	if [ -n "$MAIL_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $MAIL_SYSTEM"
		fi
		cp -fr /etc/$MAIL_SYSTEM/* $LOKAHOST_BACKUP/conf/$MAIL_SYSTEM/
	fi
	if [ -n "$DNS_SYSTEM" ]; then
		if [ "$DNS_SYSTEM" = "bind9" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      ---- $DNS_SYSTEM"
			fi
			cp -fr /etc/bind/* $LOKAHOST_BACKUP/conf/$DNS_SYSTEM/
		fi
	fi
	if [ -n "$DB_SYSTEM" ]; then
		if [[ "$DB_SYSTEM" =~ "mysql" ]]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      ---- mysql"
			fi
			cp -fr /etc/mysql/* $LOKAHOST_BACKUP/conf/mysql/
		fi
		if [[ "$DB_SYSTEM" =~ "pgsql" ]]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      ---- pgsql"
			fi
			# config for postgresql is stored in /etc/postgresql/version/main/
			cp -fr /etc/postgresql/* $LOKAHOST_BACKUP/conf/pgsql/
		fi
	fi
	if [ -n "$FTP_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $FTP_SYSTEM"
		fi
		if [ "$FTP_SYSTEM" = "vsftpd" ]; then
			cp -f /etc/$FTP_SYSTEM.conf $LOKAHOST_BACKUP/conf/$FTP_SYSTEM/
		fi
		if [ "$FTP_SYSTEM" = "proftpd" ]; then
			cp -f /etc/proftpd/proftpd.conf $LOKAHOST_BACKUP/conf/$FTP_SYSTEM/
		fi
	fi
	if [ -n "$FIREWALL_SYSTEM" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $FIREWALL_SYSTEM"
		fi
		[ -e "/etc/sysconfig/iptables" ] && cp -f /etc/sysconfig/iptables $LOKAHOST_BACKUP/conf/$FIREWALL_SYSTEM/
		[ -e "/etc/iptables.rules" ] && cp -f /etc/iptables.rules $LOKAHOST_BACKUP/conf/$FIREWALL_SYSTEM/
	fi
	if [ -n "$FIREWALL_EXTENSION" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- $FIREWALL_EXTENSION"
		fi
		cp -f /etc/$FIREWALL_EXTENSION/*.conf $LOKAHOST_BACKUP/conf/$FIREWALL_EXTENSION/
		cp -f /etc/$FIREWALL_EXTENSION/*.local $LOKAHOST_BACKUP/conf/$FIREWALL_EXTENSION/
	fi
	if [ -e "/etc/ssh/sshd_config" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- sshd"
		fi
		cp -fr /etc/ssh/* $LOKAHOST_BACKUP/conf/ssh/
	fi
	if [ -d "/etc/roundcube" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- Roundcube"
		fi
		cp -fr /etc/roundcube/* $LOKAHOST_BACKUP/conf/roundcube
	fi
	if [ -d "/etc/snappymail" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- SnappyMail"
		fi
		cp -fr /etc/snappymail/* $LOKAHOST_BACKUP/conf/snappymail
	fi
	if [ -d "/etc/phpmyadmin" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- phpMyAdmin"
		fi
		cp -fr /etc/phpmyadmin/* $LOKAHOST_BACKUP/conf/phpmyadmin
	fi
	if [ -d "/etc/phppgadmin" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      ---- phppgadmin"
		fi
		cp -fr /etc/phppgadmin/* $LOKAHOST_BACKUP/conf/phppgadmin
	fi
}

upgrade_refresh_config() {
	source_conf "/usr/local/lokahost/conf/lokahost.conf"
}

upgrade_start_routine() {
	# Parse version numbers for comparison
	function check_version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

	# Remove pre-release designation from version number for upgrade scripts
	VERSION=$(echo "$VERSION" | sed "s/~\([a-zA-Z0-9].*\)//g")

	# Get list of all available version steps and create array
	upgrade_steps=$(ls -v $LOKAHOST/install/upgrade/versions/*.sh)
	for script in $upgrade_steps; do
		declare -a available_versions
		available_versions+=($(echo $script | sed "s|/usr/local/lokahost/install/upgrade/versions/||g" | sed "s|.sh||g"))
	done

	# Define variables for accessing supported versions
	# Sort version by -V due to issues with version numbers 1.4.10 and higher
	all_versions=$(printf "%s\n" "${available_versions[@]}" | sort -V)
	oldest_version=$(printf "%s\n" "$all_versions" | head -n1)
	latest_version=$(printf "%s\n" "$all_versions" | sort -V | tail -n1)

	# Check for supported versions and process necessary upgrade steps
	if [ $(check_version $latest_version) -gt $(check_version $VERSION) ]; then
		for version_step in "${available_versions[@]}"; do
			if [ $(check_version $VERSION) -lt $(check_version "$version_step") ]; then
				upgrade_step_message
				source $LOKAHOST/install/upgrade/versions/$version_step.sh
			fi
		done
		upgrade_set_version "$VERSION"
		upgrade_refresh_config
	else
		echo ""
		echo "[ ! ] The latest version of Lokahost Control Panel is already installed."
		echo "      Verifying configuration..."
		echo ""
		if [ -e "$LOKAHOST/install/upgrade/versions/$VERSION.sh" ]; then
			source $LOKAHOST/install/upgrade/versions/$VERSION.sh
		fi
		VERSION="$new_version"
		upgrade_set_version "$VERSION"
		upgrade_refresh_config
	fi

	#####################################################################
	#######     End version-specific upgrade instruction sets     #######
	#####################################################################
}

upgrade_b2_tool() {
	b2cli="/usr/local/bin/b2"
	b2lnk="https://github.com/Backblaze/B2_Command_Line_Tool/releases/download/v$b2_v/b2-linux"
	if [ -f "$b2cli" ]; then
		b2_version=$($b2cli version | grep -o -E '[0-9].[0-9].[0-9]+' | head -1)
		if version_ge "$b2_version" "$b2_v"; then
			echo "[ * ] Backblaze CLI tool is up to date ($b2_v)..."
		else
			echo "[ * ] Upgrading Backblaze CLI tool to version $b2_v..."
			rm $b2cli
			wget -O $b2cli $b2lnk > /dev/null 2>&1
			chmod +x $b2cli > /dev/null 2>&1
			if [ ! -f "$b2cli" ]; then
				echo "Error: Binary download failed, b2 doesn't work as expected."
				exit 3
			fi
		fi
	fi
}

upgrade_cloudflare_ip() {
	if [ "$WEB_SYSTEM" = "nginx" ] || [ "$PROXY_SYSTEM" = "nginx" ]; then
		cf_ips="$(curl -fsLm5 --retry 2 https://api.cloudflare.com/client/v4/ips)"

		if [ -n "$cf_ips" ] && [ "$(echo "$cf_ips" | jq -r '.success//""')" = "true" ]; then
			cf_inc="/etc/nginx/conf.d/cloudflare.inc"

			echo "[ * ] Updating Cloudflare IP Ranges for NGINX..."
			echo "# Cloudflare IP Ranges" > $cf_inc
			echo "" >> $cf_inc
			echo "# IPv4" >> $cf_inc
			for ipv4 in $(echo "$cf_ips" | jq -r '.result.ipv4_cidrs[]//""' | sort); do
				echo "set_real_ip_from $ipv4;" >> $cf_inc
			done
			echo "" >> $cf_inc
			echo "# IPv6" >> $cf_inc
			for ipv6 in $(echo "$cf_ips" | jq -r '.result.ipv6_cidrs[]//""' | sort); do
				echo "set_real_ip_from $ipv6;" >> $cf_inc
			done
			echo "" >> $cf_inc
			echo "real_ip_header CF-Connecting-IP;" >> $cf_inc
		fi
	fi
}

upgrade_phppgadmin() {
	if [ -n "$(echo $DB_SYSTEM | grep -w 'pgsql')" ]; then
		pga_release=$(cat /usr/share/phppgadmin/libraries/lib.inc.php | grep appVersion | head -n1 | cut -f2 -d\' | cut -f1 -d-)
		if version_ge "$pga_release" "pga_v"; then
			echo "[ * ] phppgadmin is up to date ($pga_release)..."
		else
			# Display upgrade information
			echo "[ * ] Upgrading phppgadmin to version $pga_v..."
			[ -d /usr/share/phppgadmin ] || mkdir -p /usr/share/phppgadmin
			# Download latest phpMyAdmin release
			wget --retry-connrefused --quiet https://github.com/lokahost/phppgadmin/releases/download/v$pga_v/phppgadmin-v$pga_v.tar.gz
			tar xzf phppgadmin-v$pga_v.tar.gz -C /usr/share/phppgadmin/

			if ! version_ge "$pga_release" "7.14.0"; then
				cp -f $LOKAHOST_INSTALL_DIR/pga/config.inc.php /etc/phppgadmin/
			fi
			if [ ! -f /usr/share/phppgadmin/conf/config.inc.php ]; then
				ln -s /etc/phppgadmin/config.inc.php /usr/share/phppgadmin/conf
			fi

			rm -f phppgadmin-v$pga_v.tar.gz
		fi
	fi
}

upgrade_phpmyadmin() {
	# Check if MariaDB/MySQL is installed on the server before attempting to install or upgrade phpMyAdmin
	if [ -n "$(echo $DB_SYSTEM | grep -w 'mysql')" ]; then
		pma_version=$(jq -r .version /usr/share/phpmyadmin/package.json)
		if version_ge "$pma_version" "$pma_v"; then
			echo "[ * ] phpMyAdmin is up to date (${pma_version})..."
			# Update permissions
			if [ -e /var/lib/phpmyadmin/blowfish_secret.inc.php ]; then
				chown root:lokahostmail /var/lib/phpmyadmin/blowfish_secret.inc.php
				chmod 0640 /var/lib/phpmyadmin/blowfish_secret.inc.php
			fi
			chown root:lokahostmail /usr/share/phpmyadmin/tmp
			chmod 0770 /usr/share/phpmyadmin/tmp
		else
			# Display upgrade information
			echo "[ * ] Upgrading phpMyAdmin to version $pma_v..."
			[ -d /usr/share/phpmyadmin ] || mkdir -p /usr/share/phpmyadmin

			# Download latest phpMyAdmin release
			wget --quiet https://files.phpmyadmin.net/phpMyAdmin/$pma_v/phpMyAdmin-$pma_v-all-languages.tar.gz

			# Unpack files
			tar xzf phpMyAdmin-$pma_v-all-languages.tar.gz

			# Delete file to prevent error
			rm -rf /usr/share/phpmyadmin/doc/html

			# Overwrite old files
			cp -rf phpMyAdmin-$pma_v-all-languages/* /usr/share/phpmyadmin

			# Set config and log directory
			sed -i "s|'configFile' => ROOT_PATH . 'config.inc.php',|'configFile' => '/etc/phpmyadmin/config.inc.php',|g" /usr/share/phpmyadmin/libraries/vendor_config.php

			# Create temporary folder and change permissions
			if [ ! -d /usr/share/phpmyadmin/tmp ]; then
				mkdir /usr/share/phpmyadmin/tmp
				chown root:lokahostmail /usr/share/phpmyadmin/tmp
				chmod 0770 /usr/share/phpmyadmin/tmp

			fi

			if [ -e /var/lib/phpmyadmin/blowfish_secret.inc.php ]; then
				chown root:lokahostmail /var/lib/phpmyadmin/blowfish_secret.inc.php
				chmod 0640 /var/lib/phpmyadmin/blowfish_secret.inc.php
			fi

			# Clean up source files
			rm -fr phpMyAdmin-$pma_v-all-languages
			rm -f phpMyAdmin-$pma_v-all-languages.tar.gz
		fi
	fi
}

upgrade_filemanager() {
	FILE_MANAGER_CHECK=$(cat $LOKAHOST/conf/lokahost.conf | grep "FILE_MANAGER='false'")
	if [ -z "$FILE_MANAGER_CHECK" ]; then
		if [ -f "$LOKAHOST/web/fm/version" ]; then
			fm_version=$(cat $LOKAHOST/web/fm/version)
		else
			fm_version="1.0.0"
		fi
		if ! version_ge "$fm_version" "$fm_v"; then
			echo "[ ! ] Upgrading File Manager to version $fm_v..."
			# Reinstall the File Manager
			$BIN/v-delete-sys-filemanager quiet yes
			$BIN/v-add-sys-filemanager quiet
		else
			echo "[ * ] File Manager is up to date ($fm_v)..."

			if [ "$UPGRADE_UPDATE_FILEMANAGER_CONFIG" = "true" ]; then
				if [ -e "$LOKAHOST/web/fm/configuration.php" ]; then
					echo "[ ! ] Updating File Manager configuration..."
					# Update configuration.php
					cp -f $LOKAHOST_INSTALL_DIR/filemanager/filegator/configuration.php $LOKAHOST/web/fm/configuration.php
					# Set environment variable for interface
					$BIN/v-change-sys-config-value 'FILE_MANAGER' 'true'
				fi
			fi
		fi
	fi
}

upgrade_roundcube() {
	if [ -n "$(echo "$WEBMAIL_SYSTEM" | grep -w 'roundcube')" ]; then
		if [ -d "/usr/share/roundcube" ]; then
			echo "[ ! ] Roundcube: Updates are currently managed using the apt package manager"
			echo "      To upgrade to the latest version of Roundcube directly from upstream, from please run the command migrate_roundcube.sh located in: /usr/local/lokahost/install/upgrade/manual/"
		else
			rc_version=$(cat /var/lib/roundcube/index.php | grep -o -E '[0-9].[0-9].[0-9]+' | head -1)
			if ! version_ge "$rc_version" "$rc_v"; then
				echo "[ ! ] Upgrading Roundcube to version $rc_v..."
				$BIN/v-add-sys-roundcube
			else
				echo "[ * ] Roundcube is up to date ($rc_v)..."
			fi
		fi
	fi
}

upgrade_snappymail() {
	if [ -n "$(echo "$WEBMAIL_SYSTEM" | grep -w 'snappymail')" ]; then
		sm_version=$(cat /var/lib/snappymail/data/VERSION)
		if ! version_ge "$sm_version" "$sm_v"; then
			echo "[ ! ] Upgrading SnappyMail to version $sm_v..."
			$BIN/v-add-sys-snappymail
		else
			echo "[ * ] SnappyMail is up to date ($sm_v)..."
		fi
	fi
}

upgrade_dependencies() {
	echo "[ ! ] Update Lokahost PHP dependencies..."
	$BIN/v-add-sys-dependencies
}

upgrade_rebuild_web_templates() {
	if [ "$UPGRADE_UPDATE_WEB_TEMPLATES" = "true" ]; then
		echo "[ ! ] Updating default web domain templates..."
		$BIN/v-update-web-templates "no" "skip"
	fi
}

upgrade_rebuild_mail_templates() {
	if [ "$UPGRADE_UPDATE_MAIL_TEMPLATES" = "true" ]; then
		echo "[ ! ] Updating default mail domain templates..."
		$BIN/v-update-mail-templates "no" "skip"
	fi
}

upgrade_rebuild_dns_templates() {
	if [ "$UPGRADE_UPDATE_DNS_TEMPLATES" = "true" ]; then
		echo "[ ! ] Updating default DNS zone templates..."
		$BIN/v-update-dns-templates
	fi
}

upgrade_rebuild_users() {
	if [ "$UPGRADE_REBUILD_USERS" = "true" ]; then
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "[ * ] Rebuilding user accounts and domains:..."
		else
			echo "[ * ] Rebuilding user accounts and domains, this may take a few minutes..."
		fi
		for user in $("$BIN/v-list-users" list); do
			export restart="no"
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $user:"
			else
				echo "      - $user..."
			fi
			if [ -n "$WEB_SYSTEM" ]; then
				if [ "$DEBUG_MODE" = "true" ]; then
					echo "      ---- Web domains..."
					$BIN/v-rebuild-web-domains "$user" 'no'
				else
					$BIN/v-rebuild-web-domains "$user" 'no' > /dev/null 2>&1
				fi
			fi
			if [ -n "$DNS_SYSTEM" ]; then
				if [ "$DEBUG_MODE" = "true" ]; then
					echo "      ---- DNS zones..."
					$BIN/v-rebuild-dns-domains "$user" 'no'
				else
					$BIN/v-rebuild-dns-domains "$user" 'no' > /dev/null 2>&1
				fi
			fi
			if [ -n "$MAIL_SYSTEM" ]; then
				if [ "$DEBUG_MODE" = "true" ]; then
					echo "      ---- Mail domains..."
					$BIN/v-rebuild-mail-domains "$user" 'no'
				else
					$BIN/v-rebuild-mail-domains "$user" 'no' > /dev/null 2>&1
				fi
			fi
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      ---- User configuration..."
				$BIN/v-rebuild-user "$user" 'no'
			else
				$BIN/v-rebuild-user "$user" 'no' > /dev/null 2>&1
			fi
		done
	fi
}

update_whitelabel_logo() {
	$BIN/v-update-white-label-logo
}

upgrade_replace_default_config() {
	syshealth_update_web_config_format
	syshealth_update_mail_config_format
	syshealth_update_mail_account_config_format
	syshealth_update_dns_config_format
	syshealth_update_db_config_format
	syshealth_update_user_config_format
}

upgrade_restart_services() {
	if [ "$UPGRADE_RESTART_SERVICES" = "true" ]; then
		echo "[ * ] Restarting services..."
		sleep 2
		if [ -n "$MAIL_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $MAIL_SYSTEM"
			fi
			$BIN/v-restart-mail 'yes'
		fi
		if [ -n "$IMAP_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $IMAP_SYSTEM"
			fi
			$BIN/v-restart-service "$IMAP_SYSTEM"
		fi
		if [ -n "$WEB_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $WEB_SYSTEM"
			fi
			$BIN/v-restart-web 'yes'
		fi
		if [ -n "$PROXY_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $PROXY_SYSTEM"
			fi
			$BIN/v-restart-proxy 'yes'
		fi
		if [ -n "$DNS_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $DNS_SYSTEM"
			fi
			$BIN/v-restart-dns 'yes'
		fi
		if [ -n "$WEB_BACKEND" ]; then
			versions_list=$($BIN/v-list-sys-php plain)
			for v in $versions_list; do
				if [ "$DEBUG_MODE" = "true" ]; then
					echo "      - php$v-fpm"
				fi
				$BIN/v-restart-service "php$v-fpm" 'yes'
			done
		fi
		if [ -n "$FTP_SYSTEM" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $FTP_SYSTEM"
			fi
			$BIN/v-restart-ftp 'yes'
		fi
		if [ -n "$FIREWALL_EXTENSION" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - $FIREWALL_EXTENSION"
			fi
			$BIN/v-restart-service "$FIREWALL_EXTENSION"
		fi
		if [ "$WEB_TERMINAL" = "true" ]; then
			if [ "$DEBUG_MODE" = "true" ]; then
				echo "      - lokahost-web-terminal"
			fi
			$BIN/v-restart-service "lokahost-web-terminal"
		fi
		# Restart SSH daemon service
		if [ "$DEBUG_MODE" = "true" ]; then
			echo "      - sshd"
		fi
		$BIN/v-restart-service ssh
	fi

	# Always restart the Lokahost Control Panel service
	if [ "$DEBUG_MODE" = "true" ]; then
		echo "      - lokahost"
	fi
	$BIN/v-restart-service lokahost
}
