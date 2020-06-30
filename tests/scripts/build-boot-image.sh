#!/usr/bin/env bash

TEST_SCRIPT=
BASE_IMAGE=
BOOT_IMAGE=
SRC_RPMS=
SRC_RPM_BASENAMES=
BOOT_IMAGE_TMP=
SUDO="sudo"
EXTRA_PKGS="grubby"

BUILD_DEVICE=
BASEDIR=$(realpath $(dirname "$0"))

echo WOWOWOWOWOOWOWOWOWOWOOWOWOWWOWOWOWOOWOWW
echo $BASEDIR

perror_exit() {
	echo $@>&2
	exit 1
}

is_mounted()
{
	findmnt -k -n $1 &>/dev/null
}

clean_up()
{
	is_mounted $BUILD_TMPMNT && $SUDO umount -f $BUILD_TMPMNT;
	[[ -d "$BUILD_TMPDIR" ]] && $SUDO rm --one-file-system -rf -- "$BUILD_TMPDIR";
	[[ -e "$BUILD_DEVICE" ]] && $SUDO losetup -d "$BUILD_DEVICE";
	sync
}

trap '
ret=$?;
clean_up
exit $ret;
' EXIT

# clean up after ourselves no matter how we die.
trap 'exit 1;' SIGINT

readonly BUILD_TMPDIR="$(mktemp -d -t kexec-kdump-boot-image.XXXXXX)"
[ -d "$BUILD_TMPDIR" ] || perror_exit "mktemp failed."
readonly BUILD_TMPMNT="$BUILD_TMPDIR/root"
mkdir -p $BUILD_TMPMNT

BASE_IMAGE=$1 && shift
if [[ ! -e $BASE_IMAGE ]]; then
	perror_exit "Base image '$BASE_IMAGE' not found"
else
	BASE_IMAGE=$(realpath "$BASE_IMAGE")
fi

BOOT_IMAGE=$1 && shift
BOOT_IMAGE_TMP=$BOOT_IMAGE.building

if [[ ! -d $(dirname $BOOT_IMAGE) ]]; then
	perror_exit "Path '$(dirname $BOOT_IMAGE)' doesn't exists"
fi

for _rpm in $@; do
	if [[ ! -e $_rpm ]]; then
		perror_exit "Base image '$1' not found"
	else
		SRC_RPM_BASENAMES+="$(basename $_rpm) "
		SRC_RPMS=$(realpath "$_rpm")
	fi
done

copy_base_image() {
	local basename=$(basename -- "$BASE_IMAGE")
	local ext="${basename##*.}"
	local name="${basename%.*}"

	if [[ "$ext" == 'xz' ]]; then
		echo "Decompressing base image..."
		cp $BASE_IMAGE $BOOT_IMAGE.building.xz
		xz -d $BOOT_IMAGE_TMP.xz
	else
		cp $BASE_IMAGE $BOOT_IMAGE_TMP
	fi
}

mount_boot_image() {
	local parts mount_source

	BUILD_DEVICE=$($SUDO losetup --show -f $BOOT_IMAGE_TMP)

	if [[ $? -ne 0 || -z $BUILD_DEVICE ]]; then
		perror_exit "failed to setup loop device"
	fi

	$SUDO partprobe $BUILD_DEVICE && sync
	parts="$(ls ${BUILD_DEVICE}p*)"
	if [[ -n "$parts" ]]; then
		if [[ $(echo "$parts" | wc -l) -gt 1 ]]; then
			perror_exit "can't handle base image with multiple partition"
		fi
		mount_source="$parts"
	else
		mount_source="$BUILD_DEVICE"
	fi

	$SUDO mount $mount_source $BUILD_TMPMNT
	if [[ $? -ne 0 ]]; then
		perror_exit "failed to setup loop device"
	fi
}

install_kexec_tools_rpm() {
	local root=$BUILD_TMPMNT
	local rpm_basenames

	pushd $root
	# TODO: Hardcorded release
	$SUDO dnf --releasever=32 --installroot=$root install -y $EXTRA_PKGS $SRC_RPMS

	# TODO: Clean up
	$SUDO chroot $root /bin/bash -c "systemctl enable kdump.service"
	$SUDO chroot $root /bin/bash -c "echo 'fedora' | passwd --stdin root"
	$SUDO chroot $root /bin/bash -c "grubby --args crashkernel=192M --update-kernel ALL"
	$SUDO chroot $root /bin/bash -c ""

	bash

	$SUDO cp $BASEDIR/trigger-kdump.sh $root/test-entry.sh
	$SUDO cp $BASEDIR/kdump-test.service $root/etc/systemd/system
	echo $SUDO cp $BASEDIR/kdump-test.service $root/etc/systemd/system

	bash

	popd
}

umount_boot_image() {
	clean_up
}

finish_boot_image() {
	mv $BOOT_IMAGE_TMP $BOOT_IMAGE
}

copy_base_image

mount_boot_image

install_kexec_tools_rpm

umount_boot_image

finish_boot_image
