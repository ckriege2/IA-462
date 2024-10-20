#!/bin/sh
# SPDX-FileCopyrightText: 2024 Splunk, Inc.
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

# shellcheck disable=SC2016
FILL_DIMENSIONS='{length(IP_address) || IP_address = "?";length(OS_version) || OS_version = "?";length(OSName) || OSName = "?";length(IPv6_Address) || IPv6_Address = "?"}'

# jscpd:ignore-start
if [ "$KERNEL" = "Linux" ] ; then
    assertHaveCommand df
    CMD='df -k --output=source,fstype,size,used,avail,pcent,itotal,iused,iavail,ipcent,target'
    if [ ! -f "/etc/os-release" ] ; then
        DEFINE="-v OSName=$(cat /etc/*release | head -n 1| awk -F" release " '{print $1}'| tr ' ' '_') -v OS_version=$(cat /etc/*release | head -n 1| awk -F" release " '{print $2}' | cut -d\. -f1) -v IP_address=$(hostname -I | cut -d\  -f1) -v IPv6_Address=$(ip -6 -brief address show scope global | xargs | cut -d ' ' -f 3 | cut -d '/' -f 1)"
    else
        DEFINE="-v OSName=$(cat /etc/*release | grep '\bNAME=' | cut -d '=' -f2 | tr ' ' '_' | cut -d\" -f2) -v OS_version=$(cat /etc/*release | grep '\bVERSION_ID=' | cut -d '=' -f2 | cut -d\" -f2) -v IP_address=$(hostname -I | cut -d\  -f1) -v IPv6_Address=$(ip -6 -brief address show scope global | xargs | cut -d ' ' -f 3 | cut -d '/' -f 1)"
    fi
    BEGIN='BEGIN { OFS = "\t" }'
    FORMAT='{OSName=OSName;OS_version=OS_version;IP_address=IP_address;IPv6_Address=IPv6_Address}'
	# shellcheck disable=SC2016
	FILTER_POST='/(devtmpfs|tmpfs)/ {next}'
    # shellcheck disable=SC2016
    PRINTF='
    function rem_pcent(val)
    {
        if(substr(val, length(val), 1)=="%")
        {val=substr(val, 1, length(val)-1); return val}
    }
    {
		if($0 ~ /^Filesystem.*/){
            sub("Mounted on","MountedOn",$0);
            $(NF+1)="OSName";
            $(NF+1)="OS_version";
            $(NF+1)="IP_address";
            $(NF+1)="IPv6_Address";
            print $0;
		}

       match($0,/^(.*[^ ]) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+%|-) +(.*)$/,a);

       if (length(a) != 0)
       { printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", a[1], a[2], a[3], a[4], a[5], rem_pcent(a[6]), a[7], a[8], a[9], rem_pcent(a[10]), a[11], OSName, OS_version, IP_address, IPv6_Address}

	}'

elif [ "$KERNEL" = "SunOS" ] ; then
    assertHaveCommandGivenPath /usr/bin/df
    CMD_1='eval /usr/bin/df -n; /usr/bin/df -g'
    CMD_2='/usr/bin/df -k'
    #Filters out Inode info from df -g output -> inodes = Value just before "total files" & ifree = Value just before "free files"
    # shellcheck disable=SC2016
	INODE_FILTER='
	/^\// {key=$1}
	{
		for(i=1;i<=NF;i++)
		{
			if($i == "total" && $(i+1) == "files")
			{
				inodes=$(i-1)
			}
			if($i == "free" && $(i+1) == "files")
			{
				ifree=$(i-1)
			}
		}
	}
	{if(NR%5==0) sub("\\(.*\\)?", "", key); print "INODE:" key, inodes, ifree}'
	CMD="${CMD_1} | ${AWK} '${INODE_FILTER}'; ${CMD_2}"
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
    FILTER_PRE='/libc_psr/ {next}'
    BEGIN='BEGIN { OFS = "\t" }'
	#Maps fsType and inode info from the output of INODE_FILTER
    # shellcheck disable=SC2016
    MAP_FS_TO_TYPE='/INODE:/ {MoInodes[$1] = $2; MoIFree[$1] = $3;} /: / {
		for(i=1;i<=NF;i++){
			if($i ~ /^\/.*/)
				keyCol=i;
			else if($i ~ /[a-zA-Z0-9]/)
				valueCol=i;
		}
		if($keyCol ~ /^\/.*:/)
			fsTypes[substr($keyCol,1,length($keyCol)-1)] = $valueCol;
		else
			fsTypes[$keyCol]=$valueCol;
	}'
	#Append Type and Inode headers to the main header and print respective fields from values stored in MAP_FS_TO_TYPE variables
    # shellcheck disable=SC2016
    PRINTF='
	{
		if($0 ~ /^Filesystem.*/){
			for(i=1;i<=NF;i++){
				if($i=="Mounted" && $(i+1)=="on"){
					mountedCol=i;
                    sub("Mounted on","MountedOn",$0);
				}
			}
			$(NF+1)="Type";
			$(NF+1)="INodes";
			$(NF+1)="IUsed";
			$(NF+1)="IFree";
			$(NF+1)="IUsePct";
            $(NF+1)="OSName";
            $(NF+1)="OS_version";
            $(NF+1)="IP_address";
            $(NF+1)="IPv6_Address";

			print $0;
		}
	}
	{
		for(i=1;i<=NF;i++)
		{
            if($i ~ /.*\%$/)
                $i=substr($i, 1, length($i)-1);

			if($i ~ /^\/\S*/ && i==mountedCol && !(fsTypes[$mountedCol]~/(devfs|ctfs|proc|mntfs|objfs|lofs|fd|tmpfs)/) && !($0 ~ /.*\/proc.*/)){
				$(NF+1)=fsTypes[$mountedCol];
				$(NF+1)=MoInodes["INODE:"$mountedCol];
				$(NF+1)=MoInodes["INODE:"$mountedCol]-MoIFree["INODE:"$mountedCol];
				$(NF+1)=MoIFree["INODE:"$mountedCol];
                if(MoInodes["INODE:"$mountedCol]>0)
				{
					$(NF+1)=int(((MoInodes["INODE:"$mountedCol]-MoIFree["INODE:"$mountedCol])*100)/MoInodes["INODE:"$mountedCol]);
				}
				else
				{
					$(NF+1)="0";
				}
				$(NF+1)=OSName;
                $(NF+1)=OS_version;
                $(NF+1)=IP_address;
                $(NF+1)=IPv6_Address;

				print $0;
			}
		}
	}'

elif [ "$KERNEL" = "AIX" ] ; then
    assertHaveCommandGivenPath /usr/bin/df
	CMD='eval /usr/sysv/bin/df -n ; /usr/bin/df -kP -F %u %f %z %l %n %p %m'
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OSVersion=$(oslevel -r | cut -d'-' -f1) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
    BEGIN='BEGIN { OFS = "\t" }'
	#Maps fsType
    # shellcheck disable=SC2016
    MAP_FS_TO_TYPE='/: / {
		for(i=1;i<=NF;i++){
			if($i ~ /^\/.*/)
				keyCol=i;
			else if($i ~ /[a-zA-Z0-9]/)
				valueCol=i;
		}
		if($keyCol ~ /^\/.*:/)
			fsTypes[substr($keyCol,1,length($keyCol)-1)] = $valueCol;
		else
			fsTypes[$keyCol]=$valueCol;
	}'
	# Append Type and Inode headers to the main header and print respective fields from values stored in MAP_FS_TO_TYPE variables
    # shellcheck disable=SC2016
    PRINTF='
	{
		if($0 ~ /^Filesystem.*/){
            sub("%Iused","IUsePct",$0);

			for(i=1;i<=NF;i++){
				if($i=="Iused") iusedCol=i;
				if($i=="Ifree") ifreeCol=i;

				if($i=="Mounted" && $(i+1)=="on"){
					mountedCol=i;
                    sub("Mounted on","MountedOn",$0);
				}
			}
			$(NF+1)="Type";
			$(NF+1)="INodes";
            $(NF+1)="OSName";
            $(NF+1)="OS_version";
            $(NF+1)="IP_address";
            $(NF+1)="IPv6_Address";

			print $0;
		}
	}
	{
		for(i=1;i<=NF;i++)
		{
            if($i ~ /.*\%$/)
                $i=substr($i, 1, length($i)-1);

			if($i ~ /^\/\S*/ && i==mountedCol && !(fsTypes[$mountedCol]~/(devfs|ctfs|proc|mntfs|objfs|lofs|fd|tmpfs)/) && !($0 ~ /.*\/proc.*/)){
				$(NF+1)=fsTypes[$mountedCol];
                $(NF+1)=$iusedCol+$ifreeCol;
                $(NF+1)=OSName;
                OS_version=OSVersion/1000;
                $(NF+1)=OS_version;
                $(NF+1)=IP_address;
                $(NF+1)=IPv6_Address;

                print $0;
			}
		}
	}'

elif [ "$KERNEL" = "HP-UX" ] ; then
    assertHaveCommand df
    assertHaveCommand fstyp
    CMD='df -Pk'
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1)"
	# shellcheck disable=SC2016
	HEADER='Filesystem\tType\tSize\tUsed\tAvail\tUsePct\tINodes\tIUsed\tIFree\tIUsePct\tOSName\tOS_version\tIP_address\tMountedOn'
	# shellcheck disable=SC2016
	HEADERIZE='/^Filesystem/ {print header; next}'
    # shellcheck disable=SC2016
    MAP_FS_TO_TYPE='{c="fstyp " $1; c | getline ft; close(c);}'
    # shellcheck disable=SC2016
    FORMAT='{size=$2; used=$3; avail=$4; usePct=$5; mountedOn=$6; $2=ft; $3=size; $4=used; $5=avail; if(substr(usePct,length(usePct),1)=="%") $6=substr(usePct, 1, length(usePct)-1); else $6=usePct; $7=mountedOn; OSName=OSName;OS_version=OS_version;IP_address=IP_address;}'
    # shellcheck disable=SC2016
    FILTER_POST='($2 ~ /^(tmpfs)$/) {next}'
    # shellcheck disable=SC2016
    PRINTF='{printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, OSName, OS_version, IP_address, $11}'
elif [ "$KERNEL" = "Darwin" ] ; then
    assertHaveCommand mount
    assertHaveCommand df
    CMD='eval mount -t nocddafs,autofs,devfs,fdesc,nfs; df -k -T nocddafs,autofs,devfs,fdesc,nfs'
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
    # shellcheck disable=SC2016
    BEGIN='BEGIN { OFS = "\t" }'
	#Maps fsType
	# shellcheck disable=SC2016
	MAP_FS_TO_TYPE='/ on / {
		for(i=1;i<=NF;i++){
			if($i=="on" && $(i+1) ~ /^\/.*/)
			{
				key=$(i+1);
			}
			if($i ~ /^\(/)
				value=substr($i,2,length($i)-2);
		}
		fsTypes[key]=value;
	}'
	# Append Type and Inode headers to the main header and print respective fields from values stored in MAP_FS_TO_TYPE variables
    # shellcheck disable=SC2016
    PRINTF='
	{
		if($0 ~ /^Filesystem.*/){
            sub("%iused","IUsePct",$0);

			for(i=1;i<=NF;i++){
				if($i=="iused") iusedCol=i;
				if($i=="ifree") ifreeCol=i;
				if($i=="Mounted" && $(i+1)=="on"){
					mountedCol=i;
                    sub("Mounted on","MountedOn",$0);
				}
			}
			$(NF+1)="Type";
			$(NF+1)="INodes";
            $(NF+1)="OSName";
            $(NF+1)="OS_version";
            $(NF+1)="IP_address";
            $(NF+1)="IPv6_Address";


			print $0;
		}
	}
	{
		for(i=1;i<=NF;i++)
		{
            if($i ~ /.*\%$/)
                $i=substr($i, 1, length($i)-1);

            if($i ~ /^\/dev\/.*s[0-9]+$/){
				sub("^/dev/", "", $i);
				sub("s[0-9]+$", "", $i);
			}

			if($i ~ /^\/\S*/ && i==mountedCol){
				$(NF+1)=fsTypes[$mountedCol];
                $(NF+1)=$iusedCol+$ifreeCol;
                $(NF+1)=OSName;
                $(NF+1)=OS_version;
                $(NF+1)=IP_address;
                $(NF+1)=IPv6_Address;
                print $0;
			}
		}
	}'

elif [ "$KERNEL" = "FreeBSD" ] ; then
    assertHaveCommand mount
    assertHaveCommand df
    CMD='eval mount -t nodevfs,nonfs,noswap,nocd9660; df -ik -t nodevfs,nonfs,noswap,nocd9660'
    # Filters have been applied to get rid of IPv6 addresses designated for special usage to extract only the global IPv6 address.
    DEFINE="-v OSName=$(uname -s) -v OS_version=$(uname -r) -v IP_address=$(ifconfig -a | grep 'inet ' | grep -v 127.0.0.1 | cut -d\  -f2 | head -n 1) -v IPv6_Address=$(ifconfig -a | grep inet6 | grep -v ' ::1 ' | grep -v ' ::1/' | grep -v ' ::1%' | grep -v ' fe80::' | grep -v ' 2002::' | grep -v ' ff00::' | head -n 1 | xargs | cut -d '/' -f 1 | cut -d '%' -f 1 | cut -d ' ' -f 2)"
    # shellcheck disable=SC2016
    BEGIN='BEGIN { OFS = "\t" }'
	#Maps fsType
	# shellcheck disable=SC2016
	MAP_FS_TO_TYPE='/ on / {
		for(i=1;i<=NF;i++){
			if($i=="on" && $(i+1) ~ /^\/.*/)
			{
				key=$(i+1);
			}
			if($i ~ /^\(/)
				value=substr($i,2,length($i)-2);
		}
		fsTypes[key]=value;
	}'
	# Append Type and Inode headers to the main header and print respective fields from values stored in MAP_FS_TO_TYPE variables
    # shellcheck disable=SC2016
    PRINTF='
	{
		if($0 ~ /^Filesystem.*/){
            sub("%iused","IUsePct",$0);

			for(i=1;i<=NF;i++){
				if($i=="iused") iusedCol=i;
				if($i=="ifree") ifreeCol=i;
				if($i=="Mounted" && $(i+1)=="on"){
					mountedCol=i;
                    sub("Mounted on","MountedOn",$0);
				}
			}
			$(NF+1)="Type";
			$(NF+1)="INodes";
            $(NF+1)="OSName";
            $(NF+1)="OS_version";
            $(NF+1)="IP_address";
            $(NF+1)="IPv6_Address";

			print $0;
		}
	}
	{
		for(i=1;i<=NF;i++)
		{
            if($i ~ /.*\%$/)
                $i=substr($i, 1, length($i)-1);

			if($i ~ /^\/\S*/ && i==mountedCol){
				$(NF+1)=fsTypes[$mountedCol];
                $(NF+1)=$iusedCol+$ifreeCol;
                $(NF+1)=OSName;
                $(NF+1)=OS_version;
                $(NF+1)=IP_address;
                $(NF+1)=IPv6_Address;
                print $0;
			}
		}
	}'

fi
# jscpd:ignore-end

# shellcheck disable=SC2086
$CMD | tee "$TEE_DEST" | $AWK $DEFINE "$BEGIN $HEADERIZE $FILTER_PRE $MAP_FS_TO_TYPE $FORMAT $FILTER_POST $NORMALIZE $FILL_DIMENSIONS $PRINTF" header="$HEADER"
echo "Cmd = [$CMD];  | $AWK $DEFINE '$BEGIN $HEADERIZE $FILTER_PRE $MAP_FS_TO_TYPE $FORMAT $FILTER_POST $NORMALIZE $FILL_DIMENSIONS $PRINTF' header=\"$HEADER\"" >>"$TEE_DEST"
