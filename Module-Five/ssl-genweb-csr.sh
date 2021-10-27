#!/bin/bash
DATE=`date +%Y%m%d`
echo Welcome to Home-TCGMI SSL generation script. This script will generate a new SSL Certificate key and sign it against the selected authority.
EMAIL=ckrieger@tcgmi.com
COUNTRYCODE=US
STATE=Michigan
CITY="Farmington Hills"
COMPANY="Those Computer Guys LLC"
OU="Home Network"
DNSNAME=ad.tcgmi.com
BASEDIR=/tmp
SPKCFGDIR=/opt/ahead/spkcfg/
mkdir -p $BASEDIR
echo "Enter hostname of system/certificate"
read HOSTNAME

echo "Enter IP address of system/certificate"
read IPADDR

echo Createing request for $HOSTNAME/$IP
openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj /emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME" -addext subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME"
#openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj "/emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME"" -addext "subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME""

echo "Do you wish to sign certificat the certificate (y/n)"
read SELFSIGN

if [ $SELFSIGN = y ];then
echo Singing Requset for $HOSTNAME
cd /opt/ssl/IALAB/WEB
openssl ca -config openssl.cnf -in $BASEDIR/$HOSTNAME.csr -days 356 -out $BASEDIR/$HOSTNAME.pem
openssl x509 -in $BASEDIR/$HOSTNAME.pem -noout -text
cat $BASEDIR/$HOSTNAME.key $BASEDIR/$HOSTNAME.pem > $BASEDIR/$HOSTNAME-combined.pem
fi
