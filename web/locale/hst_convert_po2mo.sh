#!/bin/bash
if [ ! -e /usr/bin/xgettext ]; then
	echo " **********************************************************"
	echo " * Unable to find xgettext please install gettext package *"
	echo " **********************************************************"
	exit 3
fi

lang=${1-all}

if [ "$lang" == "all" ]; then
	languages=$(ls -d "$LOKAHOST/web/locale/*/" | awk -F'/' '{print $(NF-1)}')
	for lang in $languages; do
		echo "[ * ] Update $lang "
		msgfmt "$LOKAHOST/web/locale/$lang/LC_MESSAGES/lokahost.po" -o "$LOKAHOST/web/locale/$lang/LC_MESSAGES/lokahost.mo"
	done
else
	echo "[ * ] Update $lang "
	msgfmt "$LOKAHOST/web/locale/$lang/LC_MESSAGES/lokahost.po" -o "$LOKAHOST/web/locale/$lang/LC_MESSAGES/lokahost.mo"
fi
