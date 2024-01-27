#!/bin/bash

for file in /usr/local/lokahost/bin/*; do
	echo "$file" >> ~/hestia_cli_help.txt
	[ -f "$file" ] && [ -x "$file" ] && "$file" >> ~/hestia_cli_help.txt
done

sed -i 's\/usr/local/lokahost/bin/\\' ~/hestia_cli_help.txt
