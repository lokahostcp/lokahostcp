#!/bin/bash

for file in /usr/local/lokahost/bin/*; do
	echo "$file" >> ~/lokahost_cli_help.txt
	[ -f "$file" ] && [ -x "$file" ] && "$file" >> ~/lokahost_cli_help.txt
done

sed -i 's\/usr/local/lokahost/bin/\\' ~/lokahost_cli_help.txt
