#!/bin/sh
CONF=/etc/config/qpkg.conf
QPKG_NAME="QProcFS"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
QPROCFS_CFG="$QPKG_ROOT/procfs_config.txt"
QPROCFS_BAK="/tmp/procfs_backup.txt"

case "$1" in
	start)
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
		if [ "$ENABLED" != "TRUE" ]; then
				echo "$QPKG_NAME is disabled."
				exit 1
		fi

		if [ ! -f "$QPROCFS_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QPROCFS_CFG."
			exit 1
		fi

		if [ -f "$QPROCFS_BAK" ]; then
			echo "Renamed $QPKG_NAME backup to ${QPROCFS_BAK}.orig"
			mv -f "$QPROCFS_BAK" "${QPROCFS_BAK}.orig"
		fi

		echo "Saving ProcFS value..."
		for P in `cat $QPROCFS_CFG | sed -n '/^#/!p' | cut -f 1 -d ' '`; do
			V=`cat $P`
			echo "$P $V" >> $QPROCFS_BAK
		done

		echo "Setting ProcFS..."
		cat $QPROCFS_CFG | sed -n '/^#/!p' | while read L; do
			P=`echo $L | cut -f 1 -d ' '`
			V=`echo $L | cut -f 2- -d ' '`

			echo "  * Setting '$P' to '$V'"
			echo "$V" > "$P"
		done

	;;

	stop)
		if [ ! -f "$QPROCFS_BAK" ]; then
			echo "$QPKG_NAME: Couldn't find backup $QPROCFS_BAK"
			exit 1
		fi

		echo "Restoring ProcFS..."
		cat $QPROCFS_BAK | sed -n '/^#/!p' | while read L; do
			P=`echo $L | cut -f 1 -d ' '`
			V=`echo $L | cut -f 2- -d ' '`

			echo "  * Setting '$P' to '$V'"
			echo "$V" > "$P"
		done
	;;

	restart)
		$0 stop
		$0 start
		;;

	*)
		echo "Usage: $0 {start|stop|restart}"
		exit 1
esac

exit 0
