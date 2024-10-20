#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

assertHaveCommand lsof
CMD='lsof -nPs +c 0'

# shellcheck disable=SC2016
FILTER='/Permission denied|NOFD|unknown/ {next}'

if [[ "$KERNEL" = "Linux" ]] || [[ "$KERNEL" = "HP-UX" ]] || [[ "$KERNEL" = "Darwin" ]] || [[ "$KERNEL" = "FreeBSD" ]] ; then
	if [ "$KERNEL" = "Darwin" ] ; then
		# shellcheck disable=SC2016
		FILTER='/KQUEUE|PIPE|PSXSEM/ {next}'
	elif [ "$KERNEL" = "FreeBSD" ] ; then
		if [[ $KERNEL_RELEASE =~ 11.* ]] || [[ $KERNEL_RELEASE =~ 12.* ]] || [[ $KERNEL_RELEASE =~ 13.* ]]; then
			# empty condition to allow the execution of script as is
			echo > /dev/null
		else
			failUnsupportedScript
		fi
	fi
else
	failUnsupportedScript
fi

PARSE_0='NR == 1 {
    # Extract positions and headers from the first line
    for (i = 1; i <= NF; i++) {
        positions[i] = index($0, $i)
        headers[i] = length($i)
        if (i == NF) {
            printf "%s", $i
        }
        else {
            printf "%10s ", $i
        }
    }
    printf "\n"
    next
}'
PARSE_1='{
    id = 1
    for (i = 1; i <= length(positions); i++) {
        if (i == length(positions)) {
            field = substr($0, positions[i])
        } else {
            field = substr($0, positions[i], headers[i])
        }
        if (field ~ /^ *$/) {
            field = "?"
            id--
        } else {
            field = $id
        }
        id = id + 1
        if (i == length(positions)) {
            printf "%s", field
        }
        else {
            printf "%10s ", field
        }
    }
    printf "\n"
}
'

assertHaveCommand "$CMD"
# shellcheck disable=SC2094
$CMD 2>"$TEE_DEST" | tee "$TEE_DEST" | awk "$FILTER $PARSE_0 $PARSE_1"
echo "Cmd = [$CMD 2>$TEE_DEST];  | awk -v positions=\"$positions\" -v headers=\"$headers\" \"$FILTER $PRINTF\"" >> "$TEE_DEST"
