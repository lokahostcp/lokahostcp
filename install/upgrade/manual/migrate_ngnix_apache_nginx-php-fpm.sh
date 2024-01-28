#!/bin/bash

# Function Description
# Manual upgrade script from Nginx + Apache2 + PHP-FPM to Nginx + PHP-FPM

#----------------------------------------------------------#
#                    Variable&Function                     #
#----------------------------------------------------------#

# Includes
# shellcheck source=/etc/lokahost/lokahost.conf
source /etc/lokahost/lokahost.conf
# shellcheck source=/usr/local/lokahost/func/main.sh
source $LOKAHOST/func/main.sh
# shellcheck source=/usr/local/lokahost/conf/lokahost.conf
source $LOKAHOST/conf/lokahost.conf

#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

if [ "$WEB_BACKEND" != "php-fpm" ]; then
	check_result $E_NOTEXISTS "PHP-FPM is not enabled" > /dev/null
	exit 1
fi

if [ "$WEB_SYSTEM" != "apache2" ]; then
	check_result $E_NOTEXISTS "Apache2 is not enabled" > /dev/null
	exit 1
fi

#----------------------------------------------------------#
#                       Action                             #
#----------------------------------------------------------#

# Remove apache2 from config
sed -i "/^WEB_PORT/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^WEB_SSL/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^WEB_SSL_PORT/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^WEB_RGROUPS/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^WEB_SYSTEM/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf

# Remove nginx (proxy) from config
sed -i "/^PROXY_PORT/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^PROXY_SSL_PORT/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf
sed -i "/^PROXY_SYSTEM/d" $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $LOKAHOST/conf/lokahost.conf
echo "WEB_SSL='openssl'" >> $LOKAHOST/conf/lokahost.conf
echo "WEB_SSL_PORT='443'" >> $LOKAHOST/conf/lokahost.conf
echo "WEB_SYSTEM='nginx'" >> $LOKAHOST/conf/lokahost.conf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $LOKAHOST/conf/defaults/lokahost.conf
echo "WEB_SSL='openssl'" >> $LOKAHOST/conf/defaults/lokahost.conf
echo "WEB_SSL_PORT='443'" >> $LOKAHOST/conf/defaults/lokahost.conf
echo "WEB_SYSTEM='nginx'" >> $LOKAHOST/conf/defaults/lokahost.conf

rm $LOKAHOST/conf/defaults/lokahost.conf
cp $LOKAHOST/conf/lokahost.conf $LOKAHOST/conf/defaults/lokahost.conf

# Rebuild web config

for user in $($BIN/v-list-users plain | cut -f1); do
	echo $user
	for domain in $($BIN/v-list-web-domains $user plain | cut -f1); do
		$BIN/v-change-web-domain-tpl $user $domain 'default'
		$BIN/v-rebuild-web-domain $user $domain no
	done
done

systemctl restart nginx
