#!/bin/bash
RTPASS=d07fa68aaa6439b5443eb7413f6a3a96
INT1PASS=48bdc50dd56f1aa22f3ef9f642c5bf51
WEBLOC=/opt/html
openssl ca -config /opt/ssl/Home-TCGMI/openssl.cnf -gencrl -passin pass:$RTPASS > $WEBLOC/Home-TCGMI.pem.crl 
openssl ca -config /opt/ssl/Home-TCGMI/IT-Web/openssl.cnf -gencrl -passin pass:$INT1PASS> $WEBLOC/IT-Web.pem.crl
chown apache.apache /opt/html -R
chmod 440 $WEBLOC/Home-TCGMI.pem.crl $WEBLOC/IT-Web.pem.crl
