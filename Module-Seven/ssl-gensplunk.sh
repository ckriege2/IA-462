#!/bin/bash
DATE=`date +%Y%m%d`
echo Welcome to AHEAD SSL generation script. This script will generate a new SSL Certificate and key.
EMAIL=chris.krieger@thinkahead.com
COUNTRYCODE=US
STATE=Illinois
CITY=Chicago
COMPANY="AHEAD LLC"
OU="Ahead Security Practice"
DNSNAME=lab.aheadaviation.com
BASEDIR=/tmp
SPKCFGDIR=/opt/ahead/spkcfg/
mkdir -p $BASEDIR
while read HOSTNAME IPADDR APPLOC
do
echo Createing request for $HOSTNAME
openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj /emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME" -addext subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME"
#openssl req -nodes -newkey rsa:2048 -keyout $BASEDIR/$HOSTNAME.key -out $BASEDIR/$HOSTNAME.csr -subj "/emailAddress="$EMAIL"/C="$COUNTRYCODE"/ST="$STATE"/L="$CITY"/O="$COMPANY"/OU="$OU"/CN="$HOSTNAME"" -addext "subjectAltName=IP.1:"$IPADDR",DNS.1:"$HOSTNAME",DNS.2:"$HOSTNAME"."$DNSNAME""
done < ./data/SSL-spk.txt

echo "Do you wish to self sign certificates (y/n)"
read SELFSIGN

if [ $SELFSIGN = y ];then
while read HOSTNAME APPLOC
do 
echo Singing Requset for $HOSTNAME
openssl x509 -in $BASEDIR/$HOSTNAME.csr -signkey $BASEDIR/$HOSTNAME.key -days 356 -out $BASEDIR/$HOSTNAME.pem -req
cat $BASEDIR/$HOSTNAME.key $BASEDIR/$HOSTNAME.pem > $BASEDIR/$HOSTNAME-combined.pem
done < ./data/SSL.txt

fi

echo "Do you wish to deploy certificates to deployment server? (y/n)"
echo THIS WILL OVERWRITE CURRENT CERTIFICATES AND MAY CAUSE ISSUES!!!
read DEPLOYSSL
if [ $DEPLOYSSL = y ];then
while read HOSTNAME IPADDR APPLOC APPNAME
do
echo Deploying certificate for $HOSTNAME
mkdir $APPLOC/cert/ $APPLOC/default/ $APPLOC/local/ -p
cp $BASEDIR/$HOSTNAME-combined.pem $APPLOC/$APPNAME/cert/$HOSTNAME-combined.pem
cp $SPKCFGDIR/app.conf $APPLOC/default 
cp $SPKCFGDIR/inputs.conf $APPLOC/local/
cp $SPKCFGDIR/outputs.conf $APPLOC/local/
cp $$SPKCFGDIR/server.conf $APPLOC/local/
done < ./data/SSL.txt
fi
