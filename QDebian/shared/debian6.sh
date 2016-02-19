#!/bin/sh
#
DEB_VERSION="squeeze"

BASE_DEBIAN="/share/HDA_DATA"
BOOT_MODEL=`/bin/cat /etc/default_config/BOOT.conf 2>/dev/null`
WebShare=`/sbin/getcfg SHARE_DEF defWeb -d Qweb -f /etc/config/def_share.info`

make_base(){
	# Determine BASE installation location according to /etc/config/def_share.info
	VOL_BASE=`/sbin/getcfg SHARE_DEF defVolMP -d "" -f /etc/config/def_share.info`
	if [ -z $VOL_BASE ] ; then
		echo "The Public share not found."
		return 1
	fi
}

mount_deb(){
	cp /etc/resolv.conf /etc/hostname /etc/hosts $DEB_BASE/etc
	mount -o bind /dev $DEB_BASE/dev
	mount -o bind /dev/pts $DEB_BASE/dev/pts
	if [ "$BOOT_MODEL" = "TS-NASARM" ] ; then
		mount -o bind /proc $DEB_BASE/proc
	else
		mount -t proc proc $DEB_BASE/proc
	fi

	## source other_mount
	source $QPKG_DIR/other_mount
}

umount_deb(){
## ignore error
	## other umount
	source $QPKG_DIR/other_umount

	umount $DEB_BASE/proc
	umount $DEB_BASE/dev/pts
	umount $DEB_BASE/dev
	if test $? -ne 0
	then
		/bin/sleep 2
		umount $DEB_BASE/dev
	fi

}

start_services(){
for i in ${QPKG_DIR}/services/${DEB_VERSION}/S??* ;do
	case "$i" in
	*.sh)
		# Source shell script for speed.
		(
		trap - INT QUIT TSTP
		set start
		. $i
		)
		;;
	*)
			if [ -e $i ] ; then
				$i start
			else
				echo "Link $i certernly incorrect"
			fi
		;;
	esac
done
}

stop_services(){
for i in $QPKG_DIR/services/${DEB_VERSION}/K??* ;do
	case "$i" in
	*.sh)
		# Source shell script for speed.
		(
		trap - INT QUIT TSTP
		set stop
		. $i
		)
		;;
	*)
		# No sh extension, so fork subprocess.
			if [ -e $i ] ; then
				$i stop
			else
				echo "Link $i certernly incorrect"
			fi
		;;
	esac
done
}

########### START of SHELL script
make_base
####
QPKG_DIR=${VOL_BASE}/.qpkg/debian6
###
########## TEST if first start
if [ ! -e /root/.debian6_lock ] ; then
	## clean all DEB_BASE and CURRENT_VERSION ... in case of crash ...
	AVAL=`grep '\[' /etc/config/debian6.conf | grep -v debian6 | tr -d '\[' | tr -d '\]'`
	for i in $AVAL
	do
		/sbin/setcfg $i DEB_BASE "" -f /etc/config/debian6.conf
	done
	/sbin/setcfg debian6 CURRENT_VERSION "" -f /etc/config/debian6.conf
	### then create LINK and mod /etc/profile
	if [ ! -e /bin_deb ] ; then
		/bin/ln -s ${QPKG_DIR}/bin_deb /bin_deb
	fi
	 # adding bin_deb apps into system path ...
	/bin/cat /etc/profile | /bin/grep "PATH" | /bin/grep "/bin_deb" 1>>/dev/null 2>>/dev/null
	if [ $? -ne 0 ] ; then
		/bin/grep "PATH" /etc/profile | /bin/grep "/opt/bin" 1>>/dev/null 2>>/dev/null
		if [ $? -ne 0 ] ; then
			/bin/echo "export PATH=$PATH":/bin_deb >> /etc/profile
		else
			/bin/echo "export PATH=$PATH":/opt/bin:/opt/sbin:/bin_deb >> /etc/profile
		fi
	fi
	grep -q deb_cwd /etc/profile
	if [ $? -ne 0 ] ; then
		echo "alias deb_cwd='cd ${QPKG_DIR}'" >> /etc/profile
	fi
	### create the lock
	touch /root/.debian6_lock
fi
#####
DEB_VERSION=`/sbin/getcfg debian6 DEFAULT_VERSION -d root6 -f /etc/config/debian6.conf`
FLAG_V=0
if [ "$2" = "-v" ] ; then
	if [ ! -z $3 ] ; then
		DEB_VERSION=$3
		FLAG_V=1
	else
		echo " -v MUST have a version Number"
		/sbin/log_tool -t 2 -a "Chroot Debian -v need version to start"
		exit 1
	fi
	RESULT=`/sbin/getcfg $DEB_VERSION Enable -d "FALSE" -f /etc/config/debian6.conf`
	if  [ "$RESULT" = "FALSE" ] ; then
		echo " $DEB_VERSION is disabled or don't exist in /etc/config/debian6.conf"
			/sbin/log_tool -t 2 -a "$DEB_VERSION is disabled or don't exist in /etc/config/debian6.conf"
		exit 1
	fi
fi
DEB_BASE=${QPKG_DIR}/$DEB_VERSION
####
case "$1" in
	start)
	## test qpkg enable ...
		echo "Starting DEFAULT_VERSION or Change Default to $3 "
		RESULT=`/sbin/getcfg debian6 Enable -u -d TRUE -f /etc/config/qpkg.conf`
		if  [ "$RESULT" = "FALSE" ] ; then
			echo " Debian6 is disabled "
			exit 1
		fi
		## test id already started ...
		BASE=`/sbin/getcfg $DEB_VERSION DEB_BASE -d "" -f /etc/config/debian6.conf`
		if [ ! -z $BASE ] ; then
			echo " Debian chroot already Started $BASE "
			exit 1
		fi
		mount_deb
		echo " Root Folder : " $DEB_BASE " Debian chroot name : " $DEB_VERSION
		/sbin/setcfg $DEB_VERSION DEB_BASE $DEB_BASE -f /etc/config/debian6.conf
		CURRENT=`/sbin/getcfg debian6 CURRENT_VERSION -d "" -f /etc/config/debian6.conf`
		if [ -z $CURRENT ] ; then
			/sbin/setcfg debian6 CURRENT_VERSION ${DEB_VERSION} -f /etc/config/debian6.conf
		else
			echo " CURRENT VERSION exist no change it's a second version of chroot"
		fi
		start_services
		/sbin/log_tool -t 0 -a "Chroot Debian $DEB_VERSION in : $DEB_BASE Started"
		;;
	stop)
		DEB_BASE=`/sbin/getcfg $DEB_VERSION DEB_BASE -d "" -f /etc/config/debian6.conf`
		if [ "$DEB_BASE" = "" ] ; then
			echo "Stop : Nothing to do VERSION $DEB_VERSION not started"
			exit 0
		fi
		stop_services
		umount_deb
		/sbin/setcfg $DEB_VERSION DEB_BASE "" -f /etc/config/debian6.conf
		CURRENT=`/sbin/getcfg debian6 CURRENT_VERSION -d "" -f /etc/config/debian6.conf`
		if [ "$CURRENT" = "$DEB_VERSION" ] ; then
			/sbin/setcfg debian6 CURRENT_VERSION "" -f /etc/config/debian6.conf
		fi
		/sbin/log_tool -t 0 -a "Chroot Debian $DEB_VERSION Stopped"
		;;
	update)
		DEB_BASE=`/sbin/getcfg $DEB_VERSION DEB_BASE -d "" -f /etc/config/debian6.conf`
		if [ "$DEB_BASE" = "" ] ; then
			echo "Update : Nothing to do VERSION $DEB_VERSION not started"
			exit 0
		fi
		/bin_deb/deb_bash -v $DEB_VERSION apt-get update
		sleep 1
		/bin_deb/deb_bash -v $DEB_VERSION apt-get -y upgrade
		;;
	restart)
		$0 stop -v $DEB_VERSION
		/bin/sleep 2
		$0 start -v $DEB_VERSION
		;;
	setqpkg_enable)
		/sbin/setcfg debian6 Enable TRUE -f /etc/config/qpkg.conf
		;;
	setqpkg_disable)
		/sbin/setcfg debian6 Enable FALSE -f /etc/config/qpkg.conf
		;;
	status)
		STAT=`/sbin/getcfg $DEB_VERSION DEB_BASE -d "" -f /etc/config/debian6.conf`
		if [ -z "$STAT" ] ; then
			echo "Default Debian6 is not up ... "
		else
			echo "Default Debian6 is up .... "
			echo "Root Folder : " $DEB_BASE " Debian chroot name : " $DEB_VERSION
		fi
			echo " CURRENT_VERSION = " `grep CURRENT /etc/config/debian6.conf | cut -f 2 -d '='`
			echo " DEFAULT_VERSION = " `grep DEFAULT /etc/config/debian6.conf | cut -f 2 -d '='`
			AVAL=`grep '\[' /etc/config/debian6.conf | grep -v debian6 | tr -d '\[' | tr -d '\]'`
			echo " VERSION available = " $AVAL
			for i in $AVAL
			do
				STAT=`/sbin/getcfg $i DEB_BASE -d "" -f /etc/config/debian6.conf`
				if [ -n "$STAT" ] ; then
					echo " VERSION $i is started BASE is : $STAT "
				fi
			done
			echo " QPKG status is (Enable value) : " `/sbin/getcfg debian6 Enable -d "Not Set" -f /etc/config/qpkg.conf`
		;;
	stop_all)
			AVAL=`grep '\[' /etc/config/debian6.conf | grep -v debian6 | tr -d '\[' | tr -d '\]'`
			for i in $AVAL
			do
				STAT=`/sbin/getcfg $i DEB_BASE -d "" -f /etc/config/debian6.conf`
				if [ -n "$STAT" ] ; then
					$0 stop -v $i
				fi
			done
		;;
	set_default)
		/sbin/setcfg debian6 DEFAULT_VERSION $DEB_VERSION -f /etc/config/debian6.conf
		;;
	set_current)
	if [ $FLAG_V -eq 1 ] ; then
		STAT=`/sbin/getcfg $DEB_VERSION DEB_BASE -d "" -f /etc/config/debian6.conf`
		if [ -n "$STAT" ] ; then
			/sbin/setcfg debian6 CURRENT_VERSION $DEB_VERSION -f /etc/config/debian6.conf
		else
			echo " This version : $DEB_VERSION don't run .... "
			exit 1
		fi
	else
		echo "Can not change CURRENT_VERSION if -v version is not used "
		exit 1
	fi
		;;
	*)
		echo "Usage : $0 (start|stop|restart|set_default|set_current|update) [-v version] "
		echo "	Or $0 (stop_all|setqpkg_enable|setqpkg_disable|status) "
		echo " "
		echo "   start|stop [-v version] ... start/stop DEFAULT_VERSION or VERSION if -v version is set "
		echo "   restart [-v version] ... stop then start DEFAULT_VERSION or VERSION if -v version is set"
		echo "   set_default -v version .... set version as new default_version "
		echo "   set_current -v version .... set CURRENT_VERSION to another running version"
		echo "   update -v version .... do apt-get update apt-get upgrade in running version "
		echo "   status ... information about default running env. "
		echo "   stop_all ... stop all chroot version started "
		echo "   setqpkg_enable|setqpkg_disable force QPKG Enable in qpkg.conf to TRUE|FALSE"
		echo " "
		echo " For Your Information actual Status of debain6 chroot "
		$0 status
		exit 1
esac

