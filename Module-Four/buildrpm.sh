#!/bin/bash
BASEDIR=/opt/rpmbuild/SOURCES/
RPMBUILDDIR=/opt/rpmbuild
BASEREPO=/opt/html/repo/noarch
sleep 1
echo "Input application name, See below for list"
ls $RPMBUILDDIR/SOURCES |grep -v .tar.gz
read APPNAME
#ln -sf $RPMBUILDDIR ~/rpmbuild
#rm -rf ~/rpmbuild/BUILD/*
echo Building source file
sleep 1
rm -rf $RPMBUILDDIR/SOURCES/$APPNAME*.tar.gz
cd $RPMBUILDDIR/SOURCES/
echo Building source gz file
mv $RPMBUILDDIR/SOURCES/$APPNAME $RPMBUILDDIR/SOURCES/$APPNAME-1
tar -zcvf $APPNAME.tar.gz $APPNAME-1
cd $RPMBUILDDIR
echo Editing Spec file
sleep 1
vim $RPMBUILDDIR/SPECS/$APPNAME.spec
echo Building RPM / Moving to repo
sleep 1
rpmbuild -v -bb $RPMBUILDDIR/SPECS/$APPNAME.spec
cp $RPMBUILDDIR/RPMS/noarch/$APPNAME*.rpm $BASEREPO/
mv $RPMBUILDDIR/SOURCES/$APPNAME-1 $RPMBUILDDIR/SOURCES/$APPNAME
rm -rf $RPMBUILDDIR/SOURCES/*.tar.gz
rm -rf $RPMBUILDDIR/RPMS/noarch/$APPNAME*.rpm
echo Updating repo
/opt/scripts/updaterepo-home-tcgmi.sh
