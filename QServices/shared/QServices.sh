#!/bin/sh
CONF=/etc/config/qpkg.conf
QPKG_NAME="QServices"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
QSERVICES_CFG="$QPKG_ROOT/services_config.txt"

case "$1" in
	start)
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
		if [ "$ENABLED" != "TRUE" ]; then
				echo "$QPKG_NAME is disabled."
				exit 1
		fi

		
		if [ ! -f "$QSERVICES_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QSERVICES_CFG."
			exit 1
		fi

		echo "Stopping selected services..."
		cat $QSERVICES_CFG | sed -n '/^#/!p' | while read S; do
			if [ ! -e "$S" ]; then
				echo "  * Service '$S' doesn't exist"
				continue
			fi

			if [ ! -x "$S" ]; then
				echo "  * Cannot execute '$S'"
				continue
			fi
			$S stop
		done
		;;

	stop)
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
