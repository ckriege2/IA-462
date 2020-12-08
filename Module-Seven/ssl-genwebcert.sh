#!/bin/bash
DATE=`date +%Y%m%d`
echo Welcome to Home-TCGMI SSL generation script. This script will generate a new SSL Certificate key and sign it against the IT-Web authority.
EMAIL=ckrieger@tcgmi.com
COUNTRYCODE=US
STATE=Michigan
CITY="Farmington Hills"
COMPANY="Those Computer Guys LLC"
OU="Home Network"
DNSNAME=ad.tcgmi.com
BASEDIR=/tmp
SPKCFGDIR=/opt/ahead/spkcfg/
AUTHDIR=/opt/ssl/Home-TCGMI/IT-Web/
mkdir -p $BASEDIR
echo "Enter hostname of system/certificate"
read HOSTNAME

echo "Enter IP address of system/certificate"
read IPADDR

echo Createing request for $HOSTNAME/$IP
openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj /emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME" -addext subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME"
#openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj "/emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME"" -addext "subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME""
openssl ca -config $AUTHDIR/openssl.cnf -passin pass:48bdc50dd56f1aa22f3ef9f642c5bf51 -extensions server_cert -days 375 -notext -md sha256 -in $BASEDIR/$HOSTNAME.csr -out $BASEDIR/$HOSTNAME.pem.cer
#openssl ca -config $AUTHDIR/openssl.cnf  -extensions server_cert -days 375 -notext -md sha256 -in $BASEDIR/$HOSTNAME.csr -out $BASEDIR/$HOSTNAME.pem.cer

