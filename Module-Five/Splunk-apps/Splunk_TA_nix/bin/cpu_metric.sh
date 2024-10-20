#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

HEADER='CPU    pctUser    pctNice  pctSystem  pctIowait    pctIdle    OSName                                   OS_version  IP_address'
HEADERIZE="BEGIN {print \"$HEADER\"}"
PRINTF='{printf "%-3s  %9s  %9s  %9s  %9s  %9s    %-35s %15s  %-16s\n", cpu, pctUser, pctNice, pctSystem, pctIowait, pctIdle, OSName, OS_version, IP_address}'
FILL_DIMENSIONS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?"}'

if [ "$KERNEL" = "Linux" ] ; then
    queryHaveCommand sar
    FOUND_SAR=$?
    queryHaveCommand mpstat
    FOUND_MPSTAT=$?
    if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d '=' -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1)"
    fi
    if [ $FOUND_SAR -eq 0 ] ; then
        CMD='sar -P ALL 1 1'
        # shellcheck disable=SC2016
        FORMAT='{cpu=$(NF-6); pctUser=$(NF-5); pctNice=$(NF-4); pctSystem=$(NF-3); pctIowait=$(NF-2); pctIdle=$NF;OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    elif [ $FOUND_MPSTAT -eq 0 ] ; then
        CMD='mpstat -P ALL 1 1'
        # shellcheck disable=SC2016
        FORMAT='{cpu=$(NFIELDS-10); pctUser=$(NFIELDS-9); pctNice=$(NFIELDS-8); pctSystem=$(NFIELDS-7); pctIowait=$(NFIELDS-6); pctIdle=$NF;OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    else
        failLackMultipleCommands sar mpstat
    fi
    # shellcheck disable=SC2016
    FILTER='($0 ~ /CPU/) { if($(NF-1) ~ /gnice/){  NFIELDS=NF; } else {NFIELDS=NF+1;} next} /Average|Linux|^$|%/ {next}'
elif [ "$KERNEL" = "SunOS" ] ; then
    if [ "$SOLARIS_8" = "true" ] || [ "$SOLARIS_9" = "true" ] ; then
        CMD='eval mpstat -a -p 1 2 | tail -1 | sed "s/^[ ]*0/all/"; mpstat -p 1 2 | tail -r'
    else
        CMD='eval mpstat -aq -p 1 2 | tail -1 | sed "s/^[ ]*0/all/"; mpstat -q -p 1 2 | tail -r'
    fi
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    assertHaveCommand "$CMD"
    # shellcheck disable=SC2016
    FILTER='($1=="CPU") {exit 1}'
    # shellcheck disable=SC2016
    FORMAT='{cpu=$1; pctUser=$(NF-4); pctNice="0"; pctSystem=$(NF-3); pctIowait=$(NF-2); pctIdle=$(NF-1);OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
elif [ "$KERNEL" = "AIX" ] ; then
    queryHaveCommand mpstat
    queryHaveCommand lparstat
    FOUND_MPSTAT=$?
    FOUND_LPARSTAT=$?
    DEFINE="-v OSName=$(uname -s) -v OSVersion=$(oslevel -r |  cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    if [ $FOUND_MPSTAT -eq 0 ] && [ $FOUND_LPARSTAT -eq 0 ] ; then
        # Get extra fields from lparstat
        COUNT=$(lparstat | grep " app" | wc -l)
        if [ $COUNT -gt 0 ] ; then
            # Fetch value from "app" column of lparstat output
            FETCH_APP_COL_NUM='BEGIN {app_col_num = 8}
            {
                if($0 ~ /System configuration|^$/) {next}
                if($0 ~ / app/)
                {
                    for(i=1; i<=NF; i++)
                    {
                        if($i == "app")
                        {
                            app_col_num = i;
                            break;
                        }
                    }
                    print app_col_num;
                    exit 0;
                }
            }'
            APP_COL_NUM=$(lparstat | awk "$FETCH_APP_COL_NUM")
            CPUPool=$(lparstat | tail -1 | awk -v APP_COL_NUM=$APP_COL_NUM -F " " '{print $APP_COL_NUM}')
        else
            CPUPool=0
        fi
        # Fetch other required fields from lparstat output
        OnlineVirtualCPUs=$(lparstat -i | grep "Online Virtual CPUs" | awk -F " " '{print $NF}')
        EntitledCapacity=$(lparstat -i | grep "Entitled Capacity  " | awk -F " " '{print $NF}')
        DEFINE_LPARSTAT_FIELDS="-v CPUPool=$CPUPool -v OnlineVirtualCPUs=$OnlineVirtualCPUs -v EntitledCapacity=$EntitledCapacity"

        # Get cpu stats using mpstat command and manipulate the output for adding extra fields
        CMD='mpstat -a 1 1'
        # shellcheck disable=SC2016
        FORMAT='BEGIN {flag = 0}
        {
            if($0 ~ /System configuration|^$/) {next}
            if(flag == 1)
            {
                for(i=NF+7; i>=7; i--)
                {
                    $i = $(i-6);
                }
                # Prepend OSName, OS_version, IP_address values
                $1 = OSName;
                $2 = OSVersion/1000;
                $3 = IP_address;
                # Prepend lparstat field values
                if($0 ~ /ALL/)
                {
                    $4 = CPUPool;
                    $5 = OnlineVirtualCPUs;
                    $6 = EntitledCapacity;
                }
                else
                {
                    $4 = "-";
                    $5 = "-";
                    $6 = "-";
                }
            }
            if($0 ~ /cpu /)
            {
                for(i=NF+7; i>=7; i--)
                {
                    $i = $(i-6);
                }
                # Prepend OSName, OS_version, IP_address headers
                $1 = "OSName";
                $2 = "OS_version";
                $3 = "IP_address";
                # Prepend lparstat field headers
                $4 = "CPUPool";
                $5 = "OnlineVirtualCPUs";
                $6 = "EntitledCapacity";
                flag = 1;
            }
            for(i=1; i<=NF; i++)
            {
                printf "%17s ", $i;
            }
            print "";
        }'
    fi
    $CMD | tee "$TEE_DEST" | $AWK $DEFINE $DEFINE_LPARSTAT_FIELDS "$FORMAT $FILL_DIMENSIONS"
    echo "Cmd = [$CMD];  | $AWK $DEFINE $DEFINE_LPARSTAT_FIELDS '$FORMAT $FILL_DIMENSIONS'" >>"$TEE_DEST"
    exit
elif [ "$KERNEL" = "Darwin" ] ; then
    HEADER='CPU    pctUser  pctSystem    pctIdle    OSName                                   OS_version  IP_address'
    HEADERIZE="BEGIN {print \"$HEADER\"}"
    PRINTF='{printf "%-3s  %9s  %9s  %9s    %-35s %15s  %-16s\n", cpu, pctUser, pctSystem, pctIdle, OSName, OS_version, IP_address}'
    # top command here is used to get a single instance of cpu metrics
    CMD='top -l 1'
    assertHaveCommand "$CMD"
    # FILTER here skips all the rows that doesn't match "CPU".
    # shellcheck disable=SC2016
    FILTER='($1 !~ "CPU") {next;}'

    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    # FORMAT here removes '%'in the end of the metrics.
    # shellcheck disable=SC2016
    FORMAT='function remove_char(string, char_to_remove) {
                                    sub(char_to_remove, "", string);
                                    return string;
                            }
                            {
                                cpu="all";
                                pctUser = remove_char($3, "%");
                                pctSystem = remove_char($5, "%");
                                pctIdle = remove_char($7, "%");
                                OSName=OSName;
                                OS_version=OS_version;
                                IP_address=IP_address;
                                }'
elif [ "$KERNEL" = "FreeBSD" ] ; then
    CMD='eval top -P -d2 c; top -d2 c'
    assertHaveCommand "$CMD"
    # shellcheck disable=SC2016
    FILTER='($1 !~ "CPU") { next; }'
    # shellcheck disable=SC2016
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    # shellcheck disable=SC2016
    FORMAT='function remove_char(string, char_to_remove) {
				sub(char_to_remove, "", string);
				return string;
			}
			{
				if ($1 == "CPU:") {
					cpu = "all";
				} else {
					cpu = remove_char($2, ":");
				}
			}
			{
				pctUser = remove_char($(NF-9), "%");
				pctNice = remove_char($(NF-7), "%");
				pctSystem = remove_char($(NF-5), "%");
				pctIdle = remove_char($(NF-1), "%");
				pctIowait = "0.0";
                OSName=OSName;
                OS_version=OS_version;
                IP_address=IP_address;
			}'
elif [ "$KERNEL" = "HP-UX" ] ; then
    queryHaveCommand sar
    FOUND_SAR=$?
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    if [ $FOUND_SAR -eq 0 ] ; then
        CMD='sar -M 1 1 ALL'
    fi
    FILTER='/HP-UX|^$|%/ {next}'
    # shellcheck disable=SC2016
    FORMAT='{k=0; if(5<NF) k=1} {cpu=$(1+k); pctUser=$(2+k); pctNice="0"; pctSystem=$(3+k); pctIowait=$(4+k); pctIdle=$(5+k); OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
fi
# shellcheck disable=SC2086
$CMD | tee "$TEE_DEST" | $AWK $DEFINE "$HEADERIZE $FILTER $FORMAT $FILL_DIMENSIONS $PRINTF" header="$HEADER"
echo "Cmd = [$CMD];  | $AWK $DEFINE '$HEADERIZE $FILTER $FORMAT $FILL_DIMENSIONS $PRINTF' header=\"$HEADER\"" >>"$TEE_DEST"
