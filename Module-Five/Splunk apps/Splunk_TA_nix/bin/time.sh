#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

queryHaveCommand ntpdate
FOUND_NTPDATE=$?

queryHaveCommand sntp
FOUND_SNTP=$?

getServer ()
{
   if [ -f    /etc/ntp.conf ] ; then         # Linux; FreeBSD; AIX; Mac OS X maybe
		CONFIG=/etc/ntp.conf
	elif [ -f  /etc/inet/ntp.conf ] ; then    # Solaris
		CONFIG=/etc/inet/ntp.conf
	elif [ -f  /private/etc/ntp.conf ] ; then # Mac OS X
		CONFIG=/private/etc/ntp.conf
	else
		CONFIG=
	fi

	SERVER_DEFAULT='0.pool.ntp.org'
	if [ "$CONFIG" = "" ] ; then
		SERVER=$SERVER_DEFAULT
	else
		# shellcheck disable=SC2016
		SERVER=$($AWK '/^server / {print $2; exit}' "$CONFIG")
		SERVER=${SERVER:-$SERVER_DEFAULT}
	fi

}

#With ntpdate
if [ $FOUND_NTPDATE -eq 0 ] ; then
	echo "Found ntpdate command" >> "$TEE_DEST"
	getServer

	CMD2="ntpdate -q $SERVER"
	echo "CONFIG=$CONFIG, SERVER=$SERVER" >> "$TEE_DEST"

#With sntp
elif [ "$KERNEL" = "Darwin" ] && [ $FOUND_SNTP -eq 0 ] ; then # Mac OS 10.14.6 or higher version
 	echo "Found sntp command" >> "$TEE_DEST"
	getServer

	CMD2="sntp $SERVER"
	echo "CONFIG=$CONFIG, SERVER=$SERVER" >> "$TEE_DEST"

#With Chrony
else
	CMD2="chronyc -n sources"
fi

CMD1='date'

assertHaveCommand $CMD1
assertHaveCommand "$CMD2"

$CMD1 | tee -a "$TEE_DEST"
echo "Cmd1 = [$CMD1]" >> "$TEE_DEST"

$CMD2 | tee -a "$TEE_DEST"
echo "Cmd2 = [$CMD2]" >> "$TEE_DEST"
