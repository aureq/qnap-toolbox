#!/bin/bash
CONF=/etc/config/qpkg.conf
QPKG_NAME="QDiskMgr"
QPKG_ROOT=`/sbin/getcfg $QPKG_NAME Install_Path -f ${CONF}`
QDISKMGR_CFG="$QPKG_ROOT/diskmgr_config.txt"

# notes: 
# 1 - the script tries to be smart but not too forceful
# for example, it will not try to forcefully start a md device
#
# 2 - in kernel 3.4.6, it seems that devices to handle md devices
# aren't automatically created because udev doesn't seems to be part
# of the distribution. At least for my qnap TS-659
# Though, on my TS-870 udev is running and handles gracefully what's
# required in /dev

case "$1" in
	start)
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
		if [ "$ENABLED" != "TRUE" ]; then
				echo "$QPKG_NAME is disabled."
				exit 1
		fi

		if [ ! -f "$QDISKMGR_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QDISKMGR_CFG."
			exit 1
		fi

		cat "$QDISKMGR_CFG" | sed -n '/^#/!p' | while read LINE; do
			DEVICES="`echo $LINE | awk '{print $1}'`"
			DEV_TYPE="`echo $LINE | awk '{print $2}'`"
			DEST_DEVICE="`echo $LINE | awk '{print $3}'`"
			DEST_DEVICE_NAME="$(basename $DEST_DEVICE)"
			PARTITIONS="`echo $LINE | cut -d ' ' -f 4- `"

			# check /proc/mdstat
			MDSTAT="$(cat /proc/mdstat | grep "^${DEST_DEVICE_NAME}")"

			# if not active then activate/assemble
			if [ "$(echo $MDSTAT | awk '{print $3}')" != "active" ]; then
				case "$DEV_TYPE" in
					mdadm)
						for DEV in `echo $DEVICES | sed 's/:/ /g'`; do
							if [ ! -e "$DEV" ]; then
								echo "$QPKG_NAME: $DEV is missing. Skipping $DEST_DEVICE"
								continue
							fi
						done
						mdadm --assemble --run $DEST_DEVICE `echo $DEVICES | sed 's/:/ /g'`
						if [ "$?" -ne "0" ]; then
							echo "$QPKG_NAME: mdadm did not returned '0'. Not continuing."
							continue
						fi

						mdadm --misc --test $DEST_DEVICE >/dev/null

						MDSTAT="$(cat /proc/mdstat | grep "^`basename $DEST_DEVICE`")"
						if [ "$(echo $MDSTAT | awk '{print $3}')" != "active" ]; then
							echo "$QPKG_NAME: $DEST_DEVICE does not appear to be active in /proc/mdstat"
							continue
						fi
					;;
					lvm)
						echo "$QPKG_NAME: 'lvm' support has not been implemented yet"
						continue
					;;
					*)
						echo "$QPKG_NAME: Only 'mdadm' and 'lvm' device types are supported"
						continue
					;;
				esac

			else
				echo "$QPKG_NAME: $DEST_DEVICE is already active according to /proc/mdstat"
			fi

			# check presence in /dev/
			if [ ! -e "$DEST_DEVICE" ]; then
				echo "$QPKG_NAME: $DEST_DEVICE is not available in /dev"
				continue
			fi

			# reload partition table
			fdisk -l $DEST_DEVICE >/dev/null
			if [ "$?" -ne "0" ]; then
				echo "$QPKG_NAME: Failed to read partition table from $DEST_DEVICE"
				continue
			fi

			# check partition devices and create them as needed
			for PART_NUM in $(parted --machine $DEST_DEVICE print | grep '^[[:alnum:]]:' | awk -F ':' '{print $1}'); do
				
				MAJOR="$(cat /sys/block/${DEST_DEVICE_NAME}/${DEST_DEVICE_NAME}p${PART_NUM}/dev | awk -F ':' '{print $1}')"
				MINOR="$(cat /sys/block/${DEST_DEVICE_NAME}/${DEST_DEVICE_NAME}p${PART_NUM}/dev | awk -F ':' '{print $2}')"

				if [ -z "$MAJOR" -o -z "$MINOR" ]; then
					echo "$QPKG_NAME: Unable to determine device major and minor for ${DEST_DEVICE}p${PART_NUM}. Device not created."
					continue
				fi

				if [ -e "${DEST_DEVICE}p${PART_NUM}" ]; then
					echo "$QPKG_NAME: ${DEST_DEVICE}p${PART_NUM} has already been created."
					continue
				else
					mknod "${DEST_DEVICE}p${PART_NUM}" b "$MAJOR" "$MINOR"
					if [ "$?" -eq "0" ]; then
						echo "$QPKG_NAME: ${DEST_DEVICE}p${PART_NUM} has been created."
					else
						echo "$QPKG_NAME: Error while attempting to create ${DEST_DEVICE}p${PART_NUM}."
						continue
					fi
				fi

			done
		done

		;;

	stop)
		if [ ! -f "$QDISKMGR_CFG" ]; then
			echo "$QPKG_NAME: Couldn't find $QDISKMGR_CFG."
			exit 1
		fi

		cat "$QDISKMGR_CFG" | sed -n '/^#/!p' | while read LINE; do
			DEVICES="`echo $LINE | awk '{print $1}'`"
			DEV_TYPE="`echo $LINE | awk '{print $2}'`"
			DEST_DEVICE="`echo $LINE | awk '{print $3}'`"
			DEST_DEVICE_NAME="$(basename $DEST_DEVICE)"
			PARTITIONS="`echo $LINE | cut -d ' ' -f 4- `"

			# check /proc/mdstat
			MDSTAT="$(cat /proc/mdstat | grep "^${DEST_DEVICE_NAME}")"


			# check /proc/mdstat and /dev/
			if [ "$(echo $MDSTAT | awk '{print $3}')" = "active" ]; then
			
				# check mount table

				# check if at least one partition is mounted
				for PART_NUM in $(parted --machine $DEST_DEVICE print | grep '^[[:alnum:]]:' | awk -F ':' '{print $1}'); do
					PART_DEVICE="${DEST_DEVICE_NAME}p${PART_NUM}"

					if [ ! -z "$(cat /proc/mounts | awk '{print $1}' | grep "$PART_DEVICE")" ]; then
						echo "$QPKG_NAME: Partition device $PART_DEVICE is already mounted. Not stopping service."
						continue
					fi
				done

				# check if the raw device is mounted
				if [ ! -z "$(cat /proc/mounts | awk '{print $1}' | grep "$DEST_DEVICE")" ]; then
					echo "$QPKG_NAME: Device $DEST_DEVICE is already mounted. Not stopping service."
					continue
				fi
			else
				echo "$QPKG_NAME: Device $DEST_DEVICE is not an active device."
				continue
			fi

			# remove /dev entries for each possible partition
			for PART_NUM in $(parted --machine $DEST_DEVICE print | grep '^[[:alnum:]]:' | awk -F ':' '{print $1}'); do
				if [ -e "${DEST_DEVICE}p${PART_NUM}" ]; then
					rm "${DEST_DEVICE}p${PART_NUM}"
				fi
			done

			# stop device
			mdadm --misc --stop "${DEST_DEVICE}"
			if [ "$?" -ne "0" ]; then
				echo "$QPKG_NAME: Failed to stop $DEST_DEVICE"
				continue
			fi
			
			# check if the device file still exists and then delete it
			if [ -e "$DEST_DEVICE" ]; then
				rm "${DEST_DEVICE}"
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
