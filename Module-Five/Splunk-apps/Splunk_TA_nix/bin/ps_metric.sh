#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# jscpd:ignore-start
# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

# shellcheck disable=SC2166
if [ "$KERNEL" = "Linux" -o "$KERNEL" = "Darwin" -o "$KERNEL" = "FreeBSD" ] ; then
    assertHaveCommand ps
    CMD='ps auxww'
    if [ "$KERNEL" = "Linux" ] ; then
        if [ ! -f "/etc/os-release" ] ; then
            DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1) -v IPv6_Address=$(ip -6 -brief address show scope global | xargs | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        else
            DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d '=' -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1) -v IPv6_Address=$(ip -6 -brief address show scope global | xargs | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        fi
    elif [ "$KERNEL" = "Darwin" -o "$KERNEL" = "FreeBSD" ] ; then
        # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
        DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
    fi
elif [ "$KERNEL" = "AIX" ] ; then
    assertHaveCommandGivenPath /usr/sysv/bin/ps
    CMD='/usr/sysv/bin/ps -eo user,pid,psr,pcpu,time,pmem,rss,vsz,tty,s,etime,args'
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(oslevel -r | cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
elif [ "$KERNEL" = "SunOS" ] ; then
    assertHaveCommandGivenPath /usr/bin/ps
    CMD='/usr/bin/ps -eo user,pid,psr,pcpu,time,pmem,rss,vsz,tty,s,etime,args'
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
elif [ "$KERNEL" = "HP-UX" ] ; then
    HEADER='USER                                   PID   PSR   pctCPU       CPUTIME  pctMEM     RSZ_KB     VSZ_KB   TTY      S          ELAPSED    OSName                                   OS_version  IP_address        COMMAND             ARGS'
    # shellcheck disable=SC2016
    FORMAT='{sub("^_", "", $1); if (NF>12) {args=$13; for (j=14; j<=NF; j++) args = args "_" $j} else args="<noArgs>"; sub("^[^\134[: -]*/", "", $12);OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    # shellcheck disable=SC2016
    PRINTF='{if (NR == 1) {print $0} else {printf "%-32.32s  %8s  %4s   %6s  %12s  %6s   %8s   %8s   %-7.7s  %1.1s  %15s    %-35s %15s  %-16s  %-100.100s  %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, OSName, OS_version, IP_address, $12, args}}'
    FILL_DIMENSIONS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?"}'
    # shellcheck disable=SC2016
    HEADERIZE='{NR == 1 && $0 = header}'

    assertHaveCommand ps
    export UNIX95=1
    CMD='ps -e -o ruser,pid,pset,pcpu,time,vsz,tty,state,etime,args'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	# shellcheck disable=SC2016
    FORMAT='{sub("^_", "", $1); if (NF>12) {args=$13; for (j=14; j<=NF; j++) args = args "_" $j} else args="<noArgs>"; sub("^[\[\]]", "", $11);OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    # shellcheck disable=SC2016
    PRINTF='if (NR == 1) {print $0} else {printf "%-14.14s  %6s  %4s   %6s  %12s  %6s   %8s   %8s   %-7.7s  %1.1s  %12s    %-35s %15s  %-16s  %-18.18s  %s\n", $1, $2, $3, $4, $5, "?", "?", $6, $7, $8, $9, $10, OSName, OS_version, IP_address, $11, arg}}'

    # shellcheck disable=SC2086
    $CMD | tee "$TEE_DEST" | $AWK $DEFINE "$HEADERIZE $FILL_DIMENSIONS $FORMAT $PRINTF"  header="$HEADER"
    echo "Cmd = [$CMD];  | $AWK $DEFINE '$HEADERIZE $FILL_DIMENSIONS $FORMAT $PRINTF' header=\"$HEADER\"" >> "$TEE_DEST"
    exit
fi

# shellcheck disable=SC2016
# awk logic for adding extra field ARGS with underscore delimiter and OSName, OS_version, IP_address
FORMAT='BEGIN {OFS = "    ";} # specify output field separator
{
    if (NR == 1) # Add extra headers/fields - ARGS,OSName,OS_version,IP_address in first (header) row
    {
        # Replace TIME with CPUTIME to solve field extraction issue (metrics index)
		sub("TIME","CPUTIME",$0);

        command_column = NF;
        $(NF+1) = "ARGS";
        $(NF+1) = "OSName";
        $(NF+1) = "OS_version";
        $(NF+1) = "IP_address";
        $(NF+1) = "IPv6_Address";

    }
    else
    {
        # If arguments exist, then append all with underscore delimeter, else specify <noArgs>
        if ($(command_column+1) != "")
        {
            args = $(command_column+1);
            for (i=command_column+2; i<=NF; i++)
            {
                args = args "_" $i;
                $i = "";
            }
            $(command_column+1) = args;
        }
        else
        {
            $(command_column+1) = "<noArgs>";
        }

        # Append OSName, OS_version, IP_address values in the last three columns
        if (OSName == "") {$(command_column+2) = "?";} else {$(command_column+2) = OSName;}
        if (OS_version == "") {$(command_column+3) = "?";} else {$(command_column+3) = OS_version;}
        if (IP_address == "") {$(command_column+4) = "?";} else {$(command_column+4) = IP_address;}
        if (IPv6_Address == "") {$(command_column+5) = "?";} else {$(command_column+5) = IPv6_Address;}

        # Remove trailing white spaces if any
        sub(/[ \t]+$/,"",$0);
    }
    print;
}'

# shellcheck disable=SC2086
# Execute the command
$CMD | tee "$TEE_DEST" | $AWK $DEFINE "$FORMAT"

echo "Cmd = [$CMD]; $AWK $DEFINE '$FORMAT'" >> "$TEE_DEST"
# jscpd:ignore-end
