#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# suggested command for testing reads: $ find / -type f 2>/dev/null | xargs wc &> /dev/null &

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

if [ "$KERNEL" = "Linux" ] ; then
	CMD='iostat -xky 1 1'
	assertHaveCommand "$CMD"
	if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d '=' -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1)"
    fi
	FILTER='/Device/ && /r\/s/ && /w\/s/ {f=1;}f'
	# shellcheck disable=SC2016
    PRINTF='{if ($0~/Device/) {printf "%s OSName OS_version IP_address \n", $0} else if (NF!=0) {printf "%s %s %s %s\n", $0, OSName, OS_version, IP_address}}'
elif [ "$KERNEL" = "SunOS" ] ; then
	CMD='iostat -xn 1 2'
	# jscpd:ignore-start
	assertHaveCommand "$CMD"
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	FILTER='/device/ && /r\/s/ && /w\/s/ {f++;} f==2'
    # shellcheck disable=SC2016
	PRINTF='{if ($0~/device/ && /r\/s/ && /w\/s/) {printf "%s OSName OS_version IP_address \n", $0} else if (NF!=0) {printf "%s %s %s %s\n", $0, OSName, OS_version, IP_address}}'
	# jscpd:ignore-end
elif [ "$KERNEL" = "AIX" ] ; then
	CMD='iostat  1 2'
	assertHaveCommand "$CMD"
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(oslevel -r | cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	FILTER='/^cd/ {next} /Disks/ && /Kb_read/ && /Kb_wrtn/ {f++;} f==2'
    # shellcheck disable=SC2016
	PRINTF='{if ($0~/Disks/ && /Kb_read/ && /Kb_wrtn/) {printf "%s OSName OS_version IP_address \n", $0} else if (NF!=0) {printf "%s %s %s %s\n", $0, OSName, OS_version/1000, IP_address}}'
elif [ "$KERNEL" = "FreeBSD" ] ; then
	CMD='iostat -x -c 2'
	assertHaveCommand "$CMD"
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	FILTER='/device/ && /r\/s/ && /w\/s/ {f++;} f==2'
    # shellcheck disable=SC2016
	PRINTF='{if ($0~/device/ && /r\/s/ && /w\/s/) {printf "%s OSName OS_version IP_address \n", $0} else if (NF!=0) {printf "%s %s %s %s\n", $0, OSName, OS_version, IP_address}}'
elif [ "$KERNEL" = "Darwin" ] ; then
	CMD="eval $SPLUNK_HOME/bin/darwin_disk_stats ; sleep 2; echo Pause; $SPLUNK_HOME/bin/darwin_disk_stats"
	# shellcheck disable=SC2086
	assertHaveCommandGivenPath $CMD
	HEADER='Device          rReq_PS      wReq_PS        rKB_PS        wKB_PS  avgWaitMillis   avgSvcMillis   bandwUtilPct    OSName                                   OS_version  IP_address'
	HEADERIZE="BEGIN {print \"$HEADER\"}"
	PRINTF='{printf "%-10s  %11s  %11s  %12s  %12s  %13s  %13s  %13s    %-35s %15s  %-16s\n", device, rReq_PS, wReq_PS, rKB_PS, wKB_PS, avgWaitMillis, avgSvcMillis, bandwUtilPct, OSName, OS_version, IP_address}'
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	# shellcheck disable=SC2016
	FILTER='BEGIN {FS="|"; after=0} /^Pause$/ {after=1; next} !/Bytes|Operations/ {next} {devices[$1]=$1; values[after,$1,$2]=$3; next}'
	FORMAT='{avgSvcMillis=bandwUtilPct="?";OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
	FUNC1='function getDeltaPS(disk, metric) {delta=values[1,disk,metric]-values[0,disk,metric]; return delta/2.0}'
	# Calculates the latency by pulling the read and write latency fields from darwin__disk_stats and evaluating their sum
	LATENCY='function getLatency(disk) {read=getDeltaPS(disk,"Latency Time (Read)"); write=getDeltaPS(disk,"Latency Time (Write)"); return expr read + write;}'
	FUNC2='function getAllDeltasPS(disk) {rReq_PS=getDeltaPS(disk,"Operations (Read)"); wReq_PS=getDeltaPS(disk,"Operations (Write)"); rKB_PS=getDeltaPS(disk,"Bytes (Read)")/1024; wKB_PS=getDeltaPS(disk,"Bytes (Write)")/1024; avgWaitMillis=getLatency(disk);}'
	SCRIPT="$HEADERIZE $FILTER $FUNC1 $LATENCY $FUNC2 END {$FORMAT for (device in devices) {getAllDeltasPS(device); $PRINTF}}"
	# shellcheck disable=SC2086
	$CMD | tee "$TEE_DEST" | awk $DEFINE "$SCRIPT"  header="$HEADER"
	echo "Cmd = [$CMD];  | awk $DEFINE '$SCRIPT' header=\"$HEADER\"" >> "$TEE_DEST"
	exit 0
fi
# shellcheck disable=SC2086
$CMD | tee "$TEE_DEST" | $AWK $DEFINE "$FILTER $PRINTF"
echo "Cmd = [$CMD];  | $AWK $DEFINE '$FILTER'" >> "$TEE_DEST"
