#!/bin/bash
#Refernce URL https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html
#Variables
SSLLOC=/opt/ssl
SCRIPTLOC=/opt/scripts
clear
echo "Enter Root Certificate name"
read SSLNAME
mkdir -p $SSLLOC/$SSLNAME
cd $SSLLOC/$SSLNAME
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 100 > crlnumber 
#cp $SCRIPTLOC/data/openssl.cnf ./
sed s/SSLNAME/$SSLNAME/g $SCRIPTLOC/data/openssl.cnf >./openssl.cnf
vim openssl.cnf
openssl genrsa -aes256 -out private/$SSLNAME.key.pem 4096
chmod 400 private/$SSLNAME.key.pem 
openssl req -config openssl.cnf -key  private/$SSLNAME.key.pem -new -x509 -days 3700 -sha256 -extensions v3_ca -out certs/$SSLNAME.cert.pem
chmod 444 certs/$SSLNAME.cert.pem
sleep 5
openssl x509 -noout -text -in certs/$SSLNAME.cert.pem