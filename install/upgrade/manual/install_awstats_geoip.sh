#!/bin/bash
# info: enable GeoIP Awstats
#
# This function enables GeoIP location lookup for
# IP addresses that are listed in awstats.

#----------------------------------------------------------#
#                    Variable&Function                     #
#----------------------------------------------------------#

# Includes
# shellcheck source=/usr/local/lokahost/func/main.sh
source $LOKAHOST/func/main.sh
# shellcheck source=/usr/local/lokahost/conf/lokahost.conf
source $LOKAHOST/conf/lokahost.conf

#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

#check if string already exists
if grep "geoip" $LOKAHOST/data/templates/web/awstats/awstats.tpl; then
	echo "Plugin allready enabled"
	exit 0
fi

#----------------------------------------------------------#
#                       Action                             #
#----------------------------------------------------------#

if [ -d /etc/awstats ]; then
	perl -MCPAN -f -e "install Geo::IP::PurePerl"
	perl -MCPAN -f -e "install Geo::IP"
	sed -i '/LoadPlugin=\"geoip GEOIP_STANDARD \/usr\/share\/GeoIP\/GeoIP.dat\"/s/^#//g' /etc/awstats/awstats.conf
	echo "LoadPlugin=\"geoip GEOIP_STANDARD /usr/share/GeoIP/GeoIP.dat\"" >> $LOKAHOST/data/templates/web/awstats/awstats.tpl

	for user in $($BIN/v-list-sys-users plain); do
		$BIN/v-rebuild-web-domains $user no
	done
fi

#----------------------------------------------------------#
#                       Lokahost                             #
#----------------------------------------------------------#

# Logging
log_history "Enabled GeoIP Awstats" '' 'admin'
log_event "$OK" "$ARGUMENTS"

exit 0
