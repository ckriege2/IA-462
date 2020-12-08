#!/bin/bash
BASEREPO=/opt/html/repo/
createrepo $BASEREPO
#createrepo $BASEREPO/Splunk-UF.el6/i386
#createrepo $BASEREPO/Splunk-UF.el7/x86_64
chown apache.apache $BASEREPO -R
chmod 750 $BASEREPO -R