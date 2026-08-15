#!/bin/bash

for file in /usr/local/lokahostcp/bin/*; do
	echo "$file" >> ~/lokahostcp_cli_help.txt
	[ -f "$file" ] && [ -x "$file" ] && "$file" >> ~/lokahostcp_cli_help.txt
done

sed -i 's\/usr/local/lokahostcp/bin/\\' ~/lokahostcp_cli_help.txt
