#!/bin/sh
CONF=/etc/config/qpkg.conf
QPKG_NAME="QMountFS"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
QMOUNTFS_CFG="$QPKG_ROOT/diskmgr_config.txt"

case "$1" in
	start)
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
		if [ "$ENABLED" != "TRUE" ]; then
				echo "$QPKG_NAME is disabled."
				exit 1
		fi

		if [ ! -f "$QMOUNTFS_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QMOUNTFS_CFG."
			exit 1
		fi

		cat "$QMOUNTFS_CFG" | sed -n '/^#/!p' | while read LINE; do
			DEVICE="`echo $LINE | awk '{print $1}'`"
			MOUNT_POINT="`echo $LINE | awk '{print $2}'`"
			FS_TYPE="`echo $LINE | awk '{print $3}'`"
			MOUNT_OPTIONS="`echo $LINE | awk '{print $4}'`"
			FORCE_MKDIR="`echo $LINE | awk '{print $5}'`"
			FORCE_FSCK="`echo $LINE | awk '{print $6}'`"

			if [ -z "$DEVICE" ]; then
				continue
			fi

			if [ ! -e "$DEVICE" ]; then
				echo "$QPKG_NAME: Cannot find $DEVICE"
				continue
			fi

			if [ -z "$MOUNT_POINT" ]; then
				echo "$QPKG_NAME: No mount point specified for $DEVICE"
				continue
			fi
				
			if [ -z "$FS_TYPE" ]; then
				echo "$QPKG_NAME: No file system type specified for $DEVICE"
				continue
			fi

			if [ -z "$MOUNT_OPTIONS" ]; then
				echo "$QPKG_NAME: No mount options specified for $DEVICE"
				continue
			fi

			if [ -z "$FORCE_MKDIR" ]; then
				FORCE_MKDIR=0
			fi

			if [ -z "$FORCE_FSCK" ]; then
				FORCE_FSCK=0
			fi

			echo "$QPKG_NAME: Processing $DEVICE"

			# check if device is mounted already and skip as needed
			if [ ! -z "$(cat /proc/mounts | awk '{print $1}' | grep "$DEVICE")" ]; then
				echo "$QPKG_NAME: $DEVICE is already mounted"
				continue
			fi

			# create target folder if instructed
			if [ ! -d "$MOUNT_POINT" -a "$FORCE_MKDIR" -eq "1" ]; then
				mkdir -p "$MOUNT_POINT"
				if [ "$?" -ne "0" ]; then
					echo "$QPKG_NAME: Failed to create mount directory $MOUNT_POINT"
					continue
				else
					echo "$QPKG_NAME: $MOUNT_POINT create for device $DEVICE"
				fi
			fi

			# perform fsck is file system is ext2, ext3 or ext4
			if [ "$FORCE_FSCK" -eq "1" ]; then

				case $FS_TYPE in
					ext*)
						echo "$QPKG_NAME: fsck requested for ${dEVICE}..."
						e2fsck_64 -n -f "$DEVICE" 2>&1 | sed 's/^\(.*\)$/e2fsck: \1/g'
						if [ "$?" -ne "0" ]; then
							echo "$QPKG_NAME: Device ${DEVICE} requires the Administrator's attention. Not mounting."
							continue;
						fi
					;;
					auto)
					;;
					*)
						echo "$QPKG_NAME: Only 'ext(2|3|4)' file system types support fsck operations"
						continue
					;;
				esac
			fi

			# attempt to mount device
			mount --types "$FS_TYPE" --options "$MOUNT_OPTIONS" "$DEVICE" "$MOUNT_POINT" 2>&1 | sed 's/^\(.*\)$/mount: \1/g'
			if [ "$?" -eq "0" ]; then
				echo "$QPKG_NAME: $DEVICE mounted in $MOUNT_POINT"
			else
				echo "$QPKG_NAME: Failed to mount $DEVICE"
				continue
			fi
		done
		;;

	stop)

		if [ ! -f "$QMOUNTFS_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QMOUNTFS_CFG."
			exit 1
		fi

		
		cat "$QMOUNTFS_CFG" | sed -n '/^#/!p' | while read LINE; do
			DEVICE="`echo $LINE | awk '{print $1}'`"
			MOUNT_POINT="`echo $LINE | awk '{print $2}'`"
			FS_TYPE="`echo $LINE | awk '{print $3}'`"
			MOUNT_OPTIONS="`echo $LINE | awk '{print $4}'`"
			FORCE_MKDIR="`echo $LINE | awk '{print $5}'`"
			FORCE_FSCK="`echo $LINE | awk '{print $6}'`"

			if [ -z "$DEVICE" ]; then
				continue
			fi

			if [ ! -e "$DEVICE" ]; then
				echo "$QPKG_NAME: Cannot find $DEVICE"
				continue
			fi

			if [ -z "$MOUNT_POINT" ]; then
				echo "$QPKG_NAME: No mount point specified for $DEVICE"
				continue
			fi
				
			echo "$QPKG_NAME: Processing $DEVICE"

			if [ ! -z "$(cat /proc/mounts | awk '{print $1}' | grep "$DEVICE")" ]; then
				umount --verbose "$DEVICE" 2>&1 | sed 's/^\(.*\)$/umount: \1/g'
				if [ "$?" -ne "0" ]; then
					echo "$QPKG_NAME: Failed to unmount $DEVICE"
				fi
				continue
			else
				echo "$QPKG_NAME: $DEVICE is not mounted"
				continue
			fi
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
