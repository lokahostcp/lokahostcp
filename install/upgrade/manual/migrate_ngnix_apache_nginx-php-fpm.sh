#!/bin/bash

# Function Description
# Manual upgrade script from Nginx + Apache2 + PHP-FPM to Nginx + PHP-FPM

#----------------------------------------------------------#
#                    Variable&Function                     #
#----------------------------------------------------------#

# Includes
# shellcheck source=/etc/lokahostcp/lokahostcp.conf
source /etc/lokahostcp/lokahostcp.conf
# shellcheck source=/usr/local/lokahostcp/func/main.sh
source $LOKAHOSTCP/func/main.sh
# shellcheck source=/usr/local/lokahostcp/conf/lokahostcp.conf
source $LOKAHOSTCP/conf/lokahostcp.conf

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
sed -i "/^WEB_PORT/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^WEB_SSL/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^WEB_SSL_PORT/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^WEB_RGROUPS/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^WEB_SYSTEM/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf

# Remove nginx (proxy) from config
sed -i "/^PROXY_PORT/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^PROXY_SSL_PORT/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf
sed -i "/^PROXY_SYSTEM/d" $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $LOKAHOSTCP/conf/lokahostcp.conf
echo "WEB_SSL='openssl'" >> $LOKAHOSTCP/conf/lokahostcp.conf
echo "WEB_SSL_PORT='443'" >> $LOKAHOSTCP/conf/lokahostcp.conf
echo "WEB_SYSTEM='nginx'" >> $LOKAHOSTCP/conf/lokahostcp.conf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $LOKAHOSTCP/conf/defaults/lokahostcp.conf
echo "WEB_SSL='openssl'" >> $LOKAHOSTCP/conf/defaults/lokahostcp.conf
echo "WEB_SSL_PORT='443'" >> $LOKAHOSTCP/conf/defaults/lokahostcp.conf
echo "WEB_SYSTEM='nginx'" >> $LOKAHOSTCP/conf/defaults/lokahostcp.conf

rm $LOKAHOSTCP/conf/defaults/lokahostcp.conf
cp $LOKAHOSTCP/conf/lokahostcp.conf $LOKAHOSTCP/conf/defaults/lokahostcp.conf

# Rebuild web config

for user in $($BIN/v-list-users plain | cut -f1); do
	echo $user
	for domain in $($BIN/v-list-web-domains $user plain | cut -f1); do
		$BIN/v-change-web-domain-tpl $user $domain 'default'
		$BIN/v-rebuild-web-domain $user $domain no
	done
done

systemctl restart nginx
