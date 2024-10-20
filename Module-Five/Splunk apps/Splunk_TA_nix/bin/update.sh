#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

TMP_ERROR_FILTER_FILE=$SPLUNK_HOME/var/run/splunk/unix_update_error_tmpfile # For filering out apt warning from stderr

if [ "$KERNEL" = "Linux" ] ; then
	assertHaveCommand date
    OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2)
	OS_FILE=/etc/os-release
	# Ubuntu doesn't have yum installed by default hence apt is being used to get the list of upgradable packages
    if [ "$OSName" = "Ubuntu" ]; then
		assertHaveCommand apt
		assertHaveCommand sed
		# sed command here replaces '/, [, ]' with ' '
		CMD='eval date ; eval apt list --upgradable | sed "s/\// /; s/\[/ /; s/\]/ /"'
		# shellcheck disable=SC2016
		PARSE_0='NR==1 {DATE=$0}'
		# shellcheck disable=SC2016
		PARSE_1='NR>2 { printf "%s package=%s ubuntu_update_stream=%s latest_package_version=%s ubuntu_architecture=%s current_package_version=%s\n", DATE, $1, $2, $3, $4, $7}'
		MESSAGE="$PARSE_0 $PARSE_1"
	elif echo "$OS_ID" | grep -qi suse; then
		assertHaveCommand zypper
		# shellcheck disable=SC2016
		CMD='eval date ; zypper list-updates'
		# shellcheck disable=SC2016
		PARSE_0='NR==1 {DATE=$0}'
		# shellcheck disable=SC2016
		PARSE_1='/^[\-+]+/ {header_found = 1; next}'
		# shellcheck disable=SC2016
		PARSE_2='header_found { gsub(/[[:space:]]*\|[[:space:]]*/, "|"); split($0, arr, /\|/); printf "%s repository=%s package=%s current_package_version=%s latest_package_version=%s sles_architecture=%s\n", DATE, arr[2], arr[3], arr[4], arr[5], arr[6]}'
		MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2"
	else
		assertHaveCommand yum

		CMD='eval date ; yum check-update'
		# shellcheck disable=SC2016
		PARSE_0='NR==1 {
			DATE=$0
			PROCESS=0
			UPDATES["addons"]=0
			UPDATES["base"]=0
			UPDATES["extras"]=0
			UPDATES["updates"]=0
		}'

		# Skip extraneous text up to first blank line.
		# shellcheck disable=SC2016
		PARSE_1='NR>1 && PROCESS==0 && $0 ~ /^[[:blank:]]*$|^$/ {
			PROCESS=1
		}'
		# shellcheck disable=SC2016
		PARSE_2='NR>1 && PROCESS==1 {
			num = split($0, update_array)
			if (num == 3) {
				# Record the update count
				UPDATES[update_array[3]] = UPDATES[update_array[3]]+1
				printf "%s package=\"%s\" package_type=\"%s\"\n", DATE, update_array[1], update_array[3]
			} else if (num==2 && update_array[1] != "") {
				printf "%s package=\"%s\"\n", DATE, update_array[1]
			}
		}'

		PARSE_3='END {
			TOTALS=""
			for (key in UPDATES) {
				TOTALS=TOTALS key "=" UPDATES[key] " "
			}
			printf "%s %s\n", DATE, TOTALS
		}'

		MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3"
	fi

elif [ "$KERNEL" = "Darwin" ] ; then
	assertHaveCommand date
	assertHaveCommand softwareupdate

	CMD='eval date ; softwareupdate -l'
	# shellcheck disable=SC2016
	PARSE_0='NR==1 {
		DATE=$0
		PROCESS=0
		TOTAL=0
	}'

	# If the first non-space character is an asterisk, assume this is the name
	# of the update. Otherwise, print the update.
	# shellcheck disable=SC2016
	PARSE_1='NR>1 && PROCESS==1 && $0 !~ /^[[:blank:]]*$/ {
		if ( $0 ~ /^[[:blank:]]*\*/ ) {
			PACKAGE="package=\"" $2 "\""
			RECOMMENDED=""
			RESTART=""
			TOTAL=TOTAL+1
		} else {
			if ( $0 ~ /recommended/ ) { RECOMMENDED="is_recommended=\"true\"" }
			if ( $0 ~ /restart/ ) { RESTART="restart_required=\"true\"" }
			printf "%s %s %s %s\n", DATE, PACKAGE, RECOMMENDED, RESTART
		}
	}'

	# Use sentinel value to skip all text prior to update list.
	# shellcheck disable=SC2016
	PARSE_2='NR>1 && PROCESS==0 && $0 ~ /found[[:blank:]]the[[:blank:]]following/ {
		PROCESS=1
	}'

	PARSE_3='END {
		printf "%s total_updates=%s\n", DATE, TOTAL
	}'

	MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3"

else
	# Exits
	failUnsupportedScript
fi

# shellcheck disable=SC2086
$CMD 2> $TMP_ERROR_FILTER_FILE | tee "$TEE_DEST" | $AWK "$MESSAGE"
# shellcheck disable=SC2086
grep -Ev "apt does not have a stable CLI interface|^[[:space:]]*$" < $TMP_ERROR_FILTER_FILE 1>&2
# shellcheck disable=SC2086
rm $TMP_ERROR_FILTER_FILE 2>/dev/null

echo "Cmd = [$CMD];  | $AWK '$MESSAGE'" >> "$TEE_DEST"
