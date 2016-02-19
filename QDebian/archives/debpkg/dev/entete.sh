#!/bin/sh
/bin/echo "Install Debian 6 Package"
make_base(){
#
BASE_GROUP="/share/HDA_DATA /share/HDB_DATA /share/HDC_DATA /share/HDD_DATA /share/HDE_DATA /share/HDF_DATA /share/HDG_DATA /share/HDH_DATA /share/MD0_DATA /share/MD1_DATA /share/MD2_DATA /share/MD3_DATA"
publicdir=`/sbin/getcfg Public path -f /etc/config/smb.conf`
if [ ! -z $publicdir ] && [ -d $publicdir ];then
        publicdirp1=`/bin/echo $publicdir | /bin/cut -d "/" -f 2`
        publicdirp2=`/bin/echo $publicdir | /bin/cut -d "/" -f 3`
        publicdirp3=`/bin/echo $publicdir | /bin/cut -d "/" -f 4`
        if [ ! -z $publicdirp1 ] && [ ! -z $publicdirp2 ] && [ ! -z $publicdirp3 ]; then
                [ -d "/${publicdirp1}/${publicdirp2}/Public" ] && VOL_BASE="/${publicdirp1}/${publicdirp2}"
        fi
fi
# 
if [ -z $VOL_BASE ]; then
        for datadirtest in $BASE_GROUP; do
                [ -d $datadirtest/Public ] && VOL_BASE="/${publicdirp1}/${publicdirp2}"
        done
fi
if [ -z $VOL_BASE ] ; then
        echo "The Public share not found."
        exit 1
fi
}
make_base
DPKG_DIR=$VOL_BASE/.qpkg/debian6/debpkg
/bin/dd if=${0} bs=1800 skip=1 | /bin/tar zxv -C $DPKG_DIR
[ $? = 0 ] || exit 1
VERSION=`getcfg debian6 CURRENT_VERSION -d "" -f /etc/config/debian6.conf`
if [ "$1" = "-v" ] ; then
 if [ -n "$2" ] ; then
  VERSION=$2
 else
  echo "-v need a chroot version"
  exit 1
 fi
fi
if [ -z "$VERSION" ] ; then
 echo "No version available"
 exit 1
fi
fullpath=$0
filename="${fullpath##*/}"
    dir="${fullpath:0:${#fullpath} - ${#filename}}" 
    base="${filename%.[^.]*}" 
    ext="${filename:${#base} + 1}"
    if [[ -z "$base" && -n "$ext" ]]; then 
        base=".$ext"
        ext=""
    fi
package_name=`echo $base | cut -f 1 -d '-'`

/bin_deb/deb_install_serv $package_name -v $VERSION
exit 0
XXXXXXXX