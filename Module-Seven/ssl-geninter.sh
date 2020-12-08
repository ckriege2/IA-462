#!/bin/bash
#Refernce URL https://jamielinux.com/docs/openssl-certificate-authority/create-the-intermediate-pair.html
#Variables
SSLLOC=/opt/ssl
SCRIPTLOC=/opt/scripts
clear
ls /opt/ssl
echo "Select Root certificate to use for signing"
read SSLNAME

echo "Enter Intermediate Certificate Name"
read INTNAME
mkdir $SSLLOC/$SSLNAME/$INTNAME/certs $SSLLOC/$SSLNAME/$INTNAME/crl $SSLLOC/$SSLNAME/$INTNAME/csr $SSLLOC/$SSLNAME/$INTNAME/newcerts $SSLLOC/$SSLNAME/$INTNAME/private -p
chmod 700 $SSLLOC/$SSLNAME/$INTNAME/private
touch $SSLLOC/$SSLNAME/$INTNAME/index.txt
echo 1000 > $SSLLOC/$SSLNAME/$INTNAME/serial
echo 1000 > $SSLLOC/$SSLNAME/$INTNAME/crlnumber
sleep 5
sed -e s/SSLNAME/$SSLNAME/ -e s/INTNAME/$INTNAME/ $SCRIPTLOC/data/openssl-intermediate.cnf > $SSLLOC/$SSLNAME/$INTNAME//openssl.cnf
vim $SSLLOC/$SSLNAME/$INTNAME/openssl.cnf
openssl genrsa -aes256  -out $SSLLOC/$SSLNAME/$INTNAME/private/$INTNAME.key.pem 4096
chmod 400 $SSLLOC/$SSLNAME/$INTNAME/private/$INTNAME.key.pem
cd $SSLLOC/$SSLNAME/
openssl req -config $SSLLOC/$SSLNAME/$INTNAME/openssl.cnf -new -sha256 -key $SSLLOC/$SSLNAME/$INTNAME//private/$INTNAME.key.pem -out $SSLLOC/$SSLNAME/$INTNAME/csr/$INTNAME.csr.pem
openssl ca -config $SSLLOC/$SSLNAME/openssl.cnf -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in $SSLLOC/$SSLNAME/$INTNAME/csr/$INTNAME.csr.pem -out $SSLLOC/$SSLNAME/$INTNAME/certs/$INTNAME.cert.pem
chmod 444 $SSLLOC/$SSLNAME/$INTNAME/certs/$INTNAME.cert.pem
sleep 5
openssl x509 -noout -text -in $SSLLOC/$SSLNAME/$INTNAME/certs/$INTNAME.cert.pem
