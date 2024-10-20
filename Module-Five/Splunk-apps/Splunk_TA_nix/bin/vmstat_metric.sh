#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

# hardware.sh is called in all commands to get CPU counts. The CPU count is required to determine
# the number of threads that waited for execution time. CPU count accounts for hyperthreaded cores so
# (load average - CPU count) gives a reasonable estimate of how many threads were waiting to execute.

HEADER='memTotalMB   memFreeMB   memUsedMB  memFreePct  memUsedPct   pgPageOut  swapUsedPct   pgSwapOut   cSwitches  interrupts       forks   processes     threads  loadAvg1mi  waitThreads    interrupts_PS    pgPageIn_PS    pgPageOut_PS    OSName                                   OS_version  IP_address'
HEADERIZE="BEGIN {print \"$HEADER\"}"
PRINTF='END {printf "%10d  %10d  %10d  %10.1f  %10.1f  %10s   %10.1f  %10s  %10s  %10s  %10s  %10s  %10s  %10.2f   %10.2f    %13.2f    %11.2f    %12.2f    %-35s %15s  %-16s\n", memTotalMB, memFreeMB, memUsedMB, memFreePct, memUsedPct, pgPageOut, swapUsedPct, pgSwapOut, cSwitches, interrupts, forks, processes, threads, loadAvg1mi, waitThreads, interrupts_PS, pgPageIn_PS, pgPageOut_PS, OSName, OS_version, IP_address}'
DERIVE='END {memUsedMB=memTotalMB-memFreeMB; memUsedPct=(100.0*memUsedMB)/memTotalMB; memFreePct=100.0-memUsedPct; swapUsedPct=swapUsed ? (100.0*swapUsed)/(swapUsed+swapFree) : 0;  waitThreads=loadAvg1mi > cpuCount ? loadAvg1mi-cpuCount : 0}'
FILL_DIMENSIONS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?"}'

if [ "$KERNEL" = "Linux" ] ; then
	assertHaveCommand uptime
	assertHaveCommand ps
	assertHaveCommand vmstat
	assertHaveCommand sar
	# shellcheck disable=SC2016
	CMD='eval uptime ; ps -e | wc -l ; ps -eT | wc -l ; vmstat -s ; `dirname $0`/hardware.sh; sar -B 1 2; sar -I SUM 1 2'
	if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d '=' -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1)"
    fi
	# shellcheck disable=SC2016
	PARSE_0='NR==1 {loadAvg1mi=0+$(NF-2)} NR==2 {processes=$1} NR==3 {threads=$1}'
	# shellcheck disable=SC2016
	PARSE_1='/total memory$/ {memTotalMB=$1/1024} /free memory$/ {memFreeMB+=$1/1024} /buffer memory$/ {memFreeMB+=$1/1024} /swap cache$/ {memFreeMB+=$1/1024}'
	# shellcheck disable=SC2016
	PARSE_2='/pages paged out$/ {pgPageOut=$1} /used swap$/ {swapUsed=$1} /free swap$/ {swapFree=$1} /pages swapped out$/ {pgSwapOut=$1}'
	# shellcheck disable=SC2016
	PARSE_3='/interrupts$/ {interrupts=$1} /CPU context switches$/ {cSwitches=$1} /forks$/ {forks=$1}'
	# shellcheck disable=SC2016
	PARSE_4='/^CPU_COUNT/ {cpuCount=$2}'
	# shellcheck disable=SC2016
	PARSE_5='($3 ~ "INTR") {nr[NR+3]} NR in nr {interrupts_PS=$3}'
	# shellcheck disable=SC2016
	PARSE_6='($3 ~ "pgpgin*") {nr2[NR+3]} NR in nr2 {pgPageIn_PS=$2; pgPageOut_PS=$3}'
	MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $DERIVE"
elif [ "$KERNEL" = "SunOS" ] ; then
	assertHaveCommand vmstat
	assertHaveCommandGivenPath /usr/sbin/swap
	assertHaveCommandGivenPath /usr/sbin/prtconf
	assertHaveCommand prstat
	assertHaveCommand sar
	if [ "$SOLARIS_8" = "true" ] || [ "$SOLARIS_9" = "true" ] ; then
		# shellcheck disable=SC2016
		CMD='eval /usr/sbin/prtconf 2>/dev/null | grep Memory ; /usr/sbin/swap -s ; vmstat    1 2 | sed "3d" ; vmstat -s ; prstat -n 1 1 1; `dirname $0`/hardware.sh; sar -gp 1 2; '
	else
		# shellcheck disable=SC2016
		CMD='eval /usr/sbin/prtconf 2>/dev/null | grep Memory ; /usr/sbin/swap -s ; vmstat -q 1 2 | sed "3d" ; vmstat -s ; prstat -n 1 1 1; `dirname $0`/hardware.sh; sar -gp 1 2'
	fi
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    # shellcheck disable=SC2016
	PARSE_0='/^Memory size:/ {memTotalMB=$3} (NR==5) {memFreeMB=$5 / 1024}'
	# shellcheck disable=SC2016
	PARSE_1='(NR==2) {swapUsed=0+$(NF-3); swapFree=0+$(NF-1)}'
	# shellcheck disable=SC2016
	PARSE_2='/pages paged out$/ {pgPageOut=$1} /pages swapped out$/ {pgSwapOut=$1}'
	# shellcheck disable=SC2016
	PARSE_3='/cpu context switches$/ {cSwitches=$1} /device interrupts$/ {interrupts=$1} / v?forks$/ {forks+=$1}'
	# shellcheck disable=SC2016
	PARSE_4='/^Total: / {processes=$2; threads=$4; loadAvg1mi=0+$(NF-2)}'
	# shellcheck disable=SC2016
	PARSE_5='/^CPU_COUNT/ {cpuCount=$2}'
	# Sample output: http://opensolarisforum.org/man/man1/sar.html
	if [ "$SOLARIS_10" = "true" ] || [ "$SOLARIS_11" = "true" ] ; then
		# shellcheck disable=SC2016
		PARSE_6='($1 ~ "atch*") {nr[NR+3]} NR in nr {pgPageIn_PS=$3;}'
		# shellcheck disable=SC2016
		PARSE_7='($3 ~ "ppgout*") {nr2[NR+3]} NR in nr2 {pgPageOut_PS=$3}'
	else
		# shellcheck disable=SC2016
		PARSE_6='($3 ~ "atch*") {nr[NR+3]} NR in nr {pgPageIn_PS=$5}'
		# shellcheck disable=SC2016
		PARSE_7='($3 ~ "pgout*") {nr2[NR+3]} NR in nr2 {pgPageOut_PS=$4}'
	fi
	MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $PARSE_7 $DERIVE"
elif [ "$KERNEL" = "AIX" ] ; then
	assertHaveCommand uptime
	assertHaveCommand ps
	assertHaveCommand vmstat
	assertHaveCommandGivenPath /usr/sbin/lsps
	assertHaveCommandGivenPath /usr/bin/svmon
	# shellcheck disable=SC2016
	CMD='eval uptime ; ps -e | wc -l ; ps -em | wc -l ; /usr/sbin/lsps -s ; vmstat    1 1 | tail -1 ; vmstat -s ; svmon; `dirname $0`/hardware.sh;'
	DEFINE="-v OSName=$(uname -s) -v OSVersion=$(oslevel -r |  cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	# shellcheck disable=SC2016
    PARSE_0='NR==1 {loadAvg1mi=0+$(NF-2)} NR==2 {processes=$1} NR==3 {threads=$1-processes }'
        # ps -em inclundes processes with there threads ( at least one), so processes must be excluded to count threads #
	# shellcheck disable=SC2016
	PARSE_1='(NR==5) {swapUsedPercentage=substr( $NF, 1, length($NF)-1 )} (NR==6) {pgPageIn_PS=0+$(NF-13); pgPageOut_PS=0+$(NF-12)}'
	# shellcheck disable=SC2016
	PARSE_2='/^memory / {memTotalMB=$2 / 256 ; memFreeMB=$4 / 256}'
	# shellcheck disable=SC2016
	PARSE_3='/paging space page outs$/ {pgPageOut=$1 ; pgSwapOut="?" }'
        # no pgSwapOut parameter and can't be monitored in AIX (by Jacky Ho, Systex)
		# shellcheck disable=SC2016
	PARSE_4='/cpu context switches$/ {cSwitches=$1} /device interrupts$/ {interrupts=$1 ; forks="?" }'
	# shellcheck disable=SC2016
	PARSE_5='/^CPU_COUNT/ {cpuCount=$2}'
	PARSE_6='{OS_version=OSVersion/1000}'
	DERIVE='END {memUsedMB=memTotalMB-memFreeMB; memUsedPct=(100.0*memUsedMB)/memTotalMB; memFreePct=100.0-memUsedPct; swapUsedPct=swapUsedPercentage ? swapUsedPercentage : 0;  waitThreads=loadAvg1mi > cpuCount ? loadAvg1mi-cpuCount : 0}'
	MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $DERIVE"
elif [ "$KERNEL" = "HP-UX" ] ; then
    assertHaveCommand uptime
    assertHaveCommand ps
    assertHaveCommand /usr/sbin/swapinfo
    assertHaveCommand vmstat
	# shellcheck disable=SC2016
    CMD='eval uptime ; ps -e | wc -l ; /usr/sbin/swapinfo -m; vmstat -f; vmstat -s; `dirname $0`/hardware.sh; vmstat 1 2'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	# shellcheck disable=SC2016
    PARSE_0='NR==1 {loadAvg1mi=0+$(NF-2)} NR==2 {processes=$1} {threads="?"}'
    # shellcheck disable=SC2016
	PARSE_1='NR==5 {swapUsed=$3; swapFree=$4}'
	# shellcheck disable=SC2016
    PARSE_2='/^memory / {memTotalMB=$2; memUsedMB=$3; memFreeMB=$4}'
	# shellcheck disable=SC2016
    PARSE_3='(NR>=8 && $2=="forks,") {forks=$1}'
	# shellcheck disable=SC2016
    PARSE_4='/pages paged out$/ {pgPageOut=$1} /pages swapped out$/ {pgSwapOut=$1}'
	# shellcheck disable=SC2016
    PARSE_5='/interrupts$/ {interrupts=$1} /cpu context switches$/ {cSwitches=$1} /forks$/ {forks=$1}'
    # shellcheck disable=SC2016
	PARSE_6='/^CPU_COUNT/ {cpuCount=$2}'
    # Sample output: http://ibgwww.colorado.edu/~lessem/psyc5112/usail/man/hpux/vmstat.1.html
	# shellcheck disable=SC2016
    PARSE_7='/^procs/ {nr[NR+3]} NR in nr {pgPageIn_PS=$8; pgPageOut_PS=$9; interrupts_PS=$13}'
    MESSAGE="$PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $PARSE_7 $DERIVE"
elif [ "$KERNEL" = "Darwin" ] ; then
	assertHaveCommand sysctl
	assertHaveCommand top
	assertHaveCommand sar
	# shellcheck disable=SC2016
	CMD='eval sysctl hw.memsize ; sysctl vm.swapusage ; top -l 1 -n 0; `dirname $0`/hardware.sh; sar -gp 1 2'
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    FUNCS='function toMB(s) {n=0+s; if (index(s,"K")) {n /= 1024} if (index(s,"G")) {n *= 1024} return n}'
	# shellcheck disable=SC2016
	PARSE_0='/^hw.memsize:/ {memTotalMB=$2 / (1024*1024)}'
	# shellcheck disable=SC2016
	PARSE_1='/^PhysMem:/ {memFreeMB=toMB($6)+toMB($10)}' # we count "inactive" as "free", since it can be made available w/o a pagein/swapin
	# shellcheck disable=SC2016
	PARSE_2='/^vm.swapusage:/ {swapUsed=toMB($7); swapFree=toMB($10)}'
	# shellcheck disable=SC2016
	PARSE_3='/^VM:/ {pgPageOut=0+$7}'
	if $OSX_GE_SNOW_LEOPARD; then
		# shellcheck disable=SC2016
		PARSE_4='/^Processes:/ {processes=$2; threads=$(NF-1)}'
	else
		# shellcheck disable=SC2016
		PARSE_4='/^Processes:/ {processes=$2; threads=$(NF-2)}'
	fi
	# shellcheck disable=SC2016
	PARSE_5='/^Load Avg:/ {loadAvg1mi=0+$3}'
	# shellcheck disable=SC2016
	PARSE_6='/^CPU_COUNT/ {cpuCount=$2}'
	# shellcheck disable=SC2016
	PARSE_7='($0 ~ "Average" && $1 ~ "pgout*") {next} {pgPageOut_PS=$2}'
	# shellcheck disable=SC2016
	PARSE_8='($0 ~ "Average" && $1 ~ "pgin*") {next} {pgPageIn_PS=$2}'
	MESSAGE="$FUNCS $PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $PARSE_7 $PARSE_8 $DERIVE"
	FILL_BLANKS='END {pgSwapOut=cSwitches=interrupts=interrupts_PS=forks="?"}'
elif [ "$KERNEL" = "FreeBSD" ] ; then
	# shellcheck disable=SC2016
	CMD='eval sysctl hw.physmem ; vmstat -s ; top -Sb 0; `dirname $0`/hardware.sh'
	DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
    FUNCS='function toMB(s) {n=0+s; if (index(s,"K")) {n /= 1024} if (index(s,"G")) {n *= 1024} return n}'
	# shellcheck disable=SC2016
	PARSE_0='(NR==1) {memTotalMB=$2 / (1024*1024)}'
	# shellcheck disable=SC2016
	PARSE_1='/pager pages paged out$/ {pgPageOut+=$1} /fork\(\) calls$/ {forks+=$1} /cpu context switches$/ {cSwitches+=$1} /interrupts$/ {interrupts+=$1}'
	# shellcheck disable=SC2016
	PARSE_2='/load averages:/ {loadAvg1mi=$6} /^[0-9]+ processes: / {processes=$1}'
	# shellcheck disable=SC2016
	PARSE_3='/^Swap: / {if(NF <= 5){ swapTotal=toMB($2); swapFree=toMB($4); swapUsed=swapTotal-swapFree; } else{ swapUsed=toMB($4); swapFree=toMB($6)}} /^Mem: / {memFreeMB=toMB($4)+toMB($12)}'
	# shellcheck disable=SC2016
	PARSE_4='/^CPU_COUNT/ {cpuCount=$2}'
	# shellcheck disable=SC2016
	PARSE_5='($3 ~ "INTR") {nr1[NR+3]} NR in nr1 {interrupts_PS=$3}'
	# shellcheck disable=SC2016
	PARSE_6='($3 ~ "pgpgin*") {nr2[NR+3]} NR in nr2 {pgPageIn_PS=$3; pgPageOut_PS=$4}'
	MESSAGE="$FUNCS $PARSE_0 $PARSE_1 $PARSE_2 $PARSE_3 $PARSE_4 $PARSE_5 $PARSE_6 $DERIVE"
	FILL_BLANKS='END {threads=pgSwapOut="?"}'
fi
# shellcheck disable=SC2086
$CMD | tee "$TEE_DEST" | $AWK $DEFINE "$HEADERIZE $MESSAGE $FILL_BLANKS $FILL_DIMENSIONS $PRINTF "  header="$HEADER"
echo "Cmd = [$CMD];  | $AWK $DEFINE '$HEADERIZE $MESSAGE $FILL_BLANKS $FILL_DIMENSIONS $PRINTF' header=\"$HEADER\"" >> "$TEE_DEST"
