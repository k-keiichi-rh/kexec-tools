#!/usr/bin/env sh
BOOT_COUNT_ARG="test_boot_count"
BOOT_COUNT=$(cat /proc/cmdline | grep -o "\b$BOOT_COUNT_ARG=[^ ]*" | cut -d '=' -f 2)

if [ -z "$BOOT_COUNT" ]; then
	BOOT_COUNT=0
fi

grubby --update-kernel ALL --args $BOOT_COUNT_ARG=$(expr $BOOT_COUNT + 1) && sync

if [ $BOOT_COUNT -eq 0 ]; then
	cat << EOF > /etc/kdump.conf
path /var/crash
core_collector makedumpfile -l --message-level 1 -d 31
EOF

	kdumpctl restart

	sync

	echo 1 > /proc/sys/kernel/sysrq
	echo c > /proc/sysrq-trigger

elif [ $BOOT_COUNT -eq 1 ]; then

	if [[ -n "ls /var/crash" ]]; then
		echo "KEXEC-TOOLS-TEST: PASSED" > /dev/ttyS0
	else
		echo "KEXEC-TOOLS-TEST: FAILED" > /dev/ttyS0
	fi

	shutdown -h 0
else
	echo "KEXEC-TOOLS-TEST: FAILED" > /dev/ttyS0
	echo "KEXEC-TOOLS-TEST-MSG: Unexpected system reboot!" > /dev/ttyS0
fi
