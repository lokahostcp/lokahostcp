#!/bin/bash

# Lokahost Control Panel upgrade script for target version 1.9.0

#######################################################################################
#######                      Place additional commands below.                   #######
#######################################################################################
####### upgrade_config_set_value only accepts true or false.                    #######
#######                                                                         #######
####### Pass through information to the end user in case of a issue or problem  #######
#######                                                                         #######
####### Use add_upgrade_message "My message here" to include a message          #######
####### in the upgrade notification email. Example:                             #######
#######                                                                         #######
####### add_upgrade_message "My message here"                                   #######
#######                                                                         #######
####### You can use \n within the string to create new lines.                   #######
#######################################################################################

upgrade_config_set_value 'UPGRADE_UPDATE_WEB_TEMPLATES' 'false'
upgrade_config_set_value 'UPGRADE_UPDATE_DNS_TEMPLATES' 'false'
upgrade_config_set_value 'UPGRADE_UPDATE_MAIL_TEMPLATES' 'false'
upgrade_config_set_value 'UPGRADE_REBUILD_USERS' 'yes'
upgrade_config_set_value 'UPGRADE_UPDATE_FILEMANAGER_CONFIG' 'false'

# update config sftp jail
$BIN/v-delete-sys-sftp-jail
$BIN/v-add-sys-sftp-jail

codename="$(lsb_release -s -c)"
apt=/etc/apt/sources.list.d

# Installing Node.js 20.x repo
if [ ! -f $apt/nodesource.list ] && [ ! -z $(which "node") ]; then
	echo "[ * ] Adding Node.js 20.x repo"
	echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x $codename main" > $apt/nodesource.list
	echo "deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x $codename main" >> $apt/nodesource.list
	curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg > /dev/null 2>&1
fi

# Check if lokahostweb exists
if [ -z "$(grep ^lokahostweb: /etc/passwd)" ]; then
	# Generate a random password
	random_password=$(generate_password '32')
	# Create the new lokahostweb user
	/usr/sbin/useradd "lokahostweb" -c "$email" --no-create-home
	# do not allow login into lokahostweb user
	echo lokahostweb:$random_password | sudo chpasswd -e
	cp $LOKAHOST_COMMON_DIR/sudo/lokahostweb /etc/sudoers.d/
	# Keep enabled for now
	# Remove sudo permissions admin user
	#rm /etc/sudoers.d/admin/
fi

# Check if cronjobs have been migrated
if [ ! -f "/var/spool/cron/crontabs/lokahostweb" ]; then
	echo "MAILTO=\"\"" > /var/spool/cron/crontabs/lokahostweb
	echo "CONTENT_TYPE=\"text/plain; charset=utf-8\"" >> /var/spool/cron/crontabs/lokahostweb
	while read line; do
		parse_object_kv_list "$line"
		if [ -n "$(echo "$CMD" | grep ^sudo)" ]; then
			echo "$MIN $HOUR $DAY $MONTH $WDAY $CMD" \
				| sed -e "s/%quote%/'/g" -e "s/%dots%/:/g" \
					>> /var/spool/cron/crontabs/lokahostweb
			$BIN/v-delete-cron-job admin "$JOB"
		fi
	done < $LOKAHOST/data/users/admin/cron.conf
	# Update permissions
	chmod 600 /var/spool/cron/crontabs/lokahostweb
	chown lokahostweb:lokahostweb /var/spool/cron/crontabs/lokahostweb

fi

chown lokahostweb:lokahostweb /usr/local/lokahost/data/sessions

packages=$(ls --sort=time $LOKAHOST/data/packages | grep .pkg)
for package in $packages; do
	if [ -z "$(grep -e 'SHELL_JAIL_ENABLED' $LOKAHOST/data/packages/$package)" ]; then
		echo "SHELL_JAIL_ENABLED='no'" >> $LOKAHOST/data/packages/$package
	fi
done

$BIN/v-add-user-notification 'admin' 'Lokahost securirty has been upgraded' 'Here should come a nice message about the upgrade and how to change the user name of the admin user!'
add_upgrade_message 'Here should come a nice message about the upgrade and how to change the user name of the admin user!'
