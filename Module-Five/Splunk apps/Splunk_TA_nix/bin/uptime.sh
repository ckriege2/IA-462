#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

PRINTF='END {printf "%s SystemUpTime=%s\n", DATE, UPTIME}'

# On HP-UX the `ps` command will only recognize the `-o` option if
# the `UNIX95` environment variable is set. So do it.
#
# Careful: The `UNIX95` environment variable affects other common
#          commands like `cp`.
if [ "$KERNEL" = "HP-UX" ]; then
        export UNIX95=1
fi

# This should work for any POSIX-compliant system, but in case it doesn't
# we have left the individual OS names here to be broken out later on.
if [ "$KERNEL" = "Linux" ] || [ "$KERNEL" = "SunOS" ] || [ "$KERNEL" = "AIX" ] || [ "$KERNEL" = "HP-UX" ] || [ "$KERNEL" = "Darwin" ] || [ "$KERNEL" = "FreeBSD" ] ; then
        assertHaveCommand date
        assertHaveCommand ps
        CMD='eval date; LC_ALL=POSIX ps -o etime= -p 1'
        # Get the date.
		# shellcheck disable=SC2016
        PARSE_0='NR==1 {DATE=$0}'
        # Parse timestamp using only POSIX AWK functions. The match, do/while,
        # and exponentiation commands may not be available on some systems.
        # shellcheck disable=SC2016
		PARSE_1='NR==2 {
						if (index($1,"-") != 0) {
							split($1, array, "-")
							UPTIME=86400*array[1]
							num=split(array[2], TIME, ":")
						} else {
							UPTIME=0
							num=split($1, TIME, ":")
						}
						for (i=num; i>0; i--) {
							SECS=TIME[i]
							for (j=num-i; j>0; j--) {
								SECS = SECS * 60
							}
							UPTIME = UPTIME + SECS
						}
					}'
        MASSAGE="$PARSE_0 $PARSE_1"
fi

$CMD | tee "$TEE_DEST" | $AWK "$HEADERIZE $MASSAGE $FILL_BLANKS $PRINTF" header="$HEADER"
echo "Cmd = [$CMD];  | $AWK '$HEADERIZE $MASSAGE $FILL_BLANKS $PRINTF' header=\"$HEADER\"" >> "$TEE_DEST"
