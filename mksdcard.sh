#!/bin/bash
 
# Determine the absolute path to the executable
# EXE will have the PWD removed so we can concatenate with the PWD safely
PWD=`pwd`
EXE=`echo $0 | sed s=$PWD==`
EXEPATH="$PWD"/"$EXE"

FILE_PATH=$PWD"/binary/"
ROOTFS_PATH=$PWD"/rootfs/"

FILE_UBOOT="u-boot.imx"
FILE_KERNEL="zImage"
FILE_DTBS="imx6ull-alpha-emmc.dtb"

#copy/paste programs
cp_progress ()
{
	CURRENTSIZE=0
	while [ $CURRENTSIZE -lt $TOTALSIZE ]
	do
		TOTALSIZE=$1;
		TOHERE=$2;
		CURRENTSIZE=`sudo du -c $TOHERE | grep total | awk {'print $1'}`
		echo -e -n "$CURRENTSIZE /  $TOTALSIZE copied \r"
		sleep 1
	done
}

# clear
cat << EOM
################################################################################
This script will create a bootable SD card from custom or pre-built binaries.
The script must be run with root permissions and from the bin directory of
the SDK
Example:
 $ sudo ./mksdboot.sh
Formatting can be skipped if the SD card is already formatted and
partitioned properly.
################################################################################
EOM
 
AMIROOT=`whoami | awk {'print $1'}`
if [ "$AMIROOT" != "root" ] ; then
 
	echo "	**** Error *** must run script with sudo"
	echo ""
	exit
fi


# check the images valid
echo " "
echo "Files to Buring:"
echo "u-boot:        $FILE_PATH$FILE_UBOOT"
echo "linux kernel:  $FILE_PATH$FILE_KERNEL" 
echo "linux dtb:     $FILE_PATH$FILE_DTBS"
echo "rootfs path:   $ROOTFS_PATH"
echo " "
echo " "

# find the avaible SD cards
echo " "
echo "Availible Drives to write images to: "
echo " "
ROOTDRIVE=`mount | grep 'on / ' | awk {'print $1'} |  cut -c6-8`
echo "#  major   minor    size   name "
cat /proc/partitions | grep -v $ROOTDRIVE | grep '\<sd.\>' | grep -n ''
echo " "
 
ENTERCORRECTLY=0
while [ $ENTERCORRECTLY -ne 1 ]
do
	read -p 'Enter Device Number: ' DEVICEDRIVENUMBER
	echo " "
	DEVICEDRIVENAME=`cat /proc/partitions | grep -v 'sda' | grep '\<sd.\>' | grep -n '' | grep "${DEVICEDRIVENUMBER}:" | awk '{print $5}'`
	echo "$DEVICEDRIVENAME"
 
 
	DRIVE=/dev/$DEVICEDRIVENAME
	DEVICESIZE=`cat /proc/partitions  | grep -v 'sda' | grep '\<sd.\>' | grep -n '' | grep "${DEVICEDRIVENUMBER}:" | awk '{print $4}'`
 
 
	if [ -n "$DEVICEDRIVENAME" ]
	then
		ENTERCORRECTLY=1
	else
		echo "Invalid selection"
	fi
 
	echo ""
done
 
echo "$DEVICEDRIVENAME was selected"
#Check the size of disk to make sure its under 16GB
if [ $DEVICESIZE -gt 17000000 ] ; then
cat << EOM
################################################################################
		**********WARNING**********
	Selected Device is greater then 16GB
	Continuing past this point will erase data from device
	Double check that this is the correct SD Card
################################################################################
EOM
	ENTERCORRECTLY=0
	DEFAULT_CHECK="y" 
	check_value=${1:-$DEFAULT_CHECK}
	while [ $ENTERCORRECTLY -ne 1 ]
	do
		read -p 'Would you like to continue [y/n] [default is '$check_value']: ' SIZECHECK
		echo ""
		echo " "
		SIZECHECK=${SIZECHECK:-$check_value}
		ENTERCORRECTLY=1
		case $SIZECHECK in
		"y")  ;;
		"n")  exit;;
		*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
		esac
		echo ""
	done
 
fi
 
echo ""
 
DRIVE=/dev/$DEVICEDRIVENAME
 
echo "Checking the device is unmounted"
for i in `ls -1 $DRIVE?`; do
	echo "unmounting device '$i'"
	umount $i 2>/dev/null
done
 
ENTERCORRECTLY=0
DEFAULT_CHECK="y" 
check_value=${1:-$DEFAULT_CHECK}
while [ $ENTERCORRECTLY -ne 1 ]
do
	read -p 'Would you like to re-partition the drive anyways [y/n] [default is '$check_value']: ' CASEPARTITION
	echo "y"
	echo " "
	CASEPARTITION=${CASEPARTITION:-$check_value}
	ENTERCORRECTLY=1
	case $CASEPARTITION in
	"y")  echo "Now partitioning $DEVICEDRIVENAME ...";PARTITION=0;;
	"n")  echo "Abort partitioning";
			exit ;;
	*)  echo "Please enter y or n";ENTERCORRECTLY=0;;
	esac
	echo ""
done
 
PARTITION=1
 
if [ "$PARTITION" -eq "1" ]
then
 
# Set the PARTS value as well
PARTS=1
cat << EOM
################################################################################
		Now making partitions
################################################################################
EOM
 
dd if=/dev/zero of=$DRIVE bs=1024 count=1024
sync
 
SIZE=`fdisk -l $DRIVE | grep Disk | awk '{print $5}'`
 
echo DISK SIZE - $SIZE bytes
 
CYLINDERS=`echo $SIZE/255/63/512 | bc`
 
cat << END | fdisk $DRIVE
n
p
1
20480
+100M
n
p
2
225280

p
w
END
 
cat << EOM
################################################################################
		Partitioning Boot
################################################################################
EOM
	mkfs.vfat -F 32 -n "BOOT" ${DRIVE}1

cat << EOM

################################################################################

		Partitioning Rootfs

################################################################################
EOM
	mkfs.ext4 -L "ROOTFS" ${DRIVE}2
	sync
	sync

fi
 
echo "Buring the $FILE_UBOOT to sdcard"
if [ -e $FILE_PATH$FILE_UBOOT ]
then
	dd if=$FILE_PATH$FILE_UBOOT of=${DRIVE} bs=1K seek=1 conv=fsync
fi

export PATH_TO_SDBOOT=boot
export PATH_TO_SDROOTFS=root

echo " "
echo "Mount the partitions "
mkdir -p $PATH_TO_SDBOOT
mkdir -p $PATH_TO_SDROOTFS

sudo mount -t vfat ${DRIVE}1 $PATH_TO_SDBOOT/
sudo mount -t ext4 ${DRIVE}2 $PATH_TO_SDROOTFS/

echo " "
echo "Emptying partitions "
echo " "
sudo rm -rf  $PATH_TO_SDBOOT/*
sudo rm -rf  $PATH_TO_SDROOTFS/*

echo ""
echo "Syncing...."
echo ""
sync
sync
sync

echo "Copying the kernel & dtb to BOOT Partition"
if [ -e $FILE_PATH$FILE_KERNEL ] && [ -e $FILE_PATH$FILE_DTBS ]
then
	cp $FILE_PATH$FILE_KERNEL $PATH_TO_SDBOOT
	echo "Kernel image copied"
	cp $FILE_PATH$FILE_DTBS $PATH_TO_SDBOOT
	echo "$FILE_DTBS copied"
fi

echo "Copying rootfs System partition"
if [ -e $ROOTFS_PATH ]
then
	TOTALSIZE=`sudo du -c $ROOTFS_PATH/* | grep total | awk {'print $1'}`
	cp $ROOTFS_PATH* $PATH_TO_SDROOTFS -drf & cp_progress $TOTALSIZE $PATH_TO_SDROOTFS
fi

echo ""
echo "Syncing...."
echo ""
sync
sync
sync
sync

echo " "
echo "Un-mount the partitions "
sudo umount -f $PATH_TO_SDBOOT
sudo umount -f $PATH_TO_SDROOTFS


echo " "
echo "Remove created temp directories "
sudo rm -rf $PATH_TO_SDROOTFS
sudo rm -rf $PATH_TO_SDBOOT
 
sleep 1
 
for i in `ls -1 $DRIVE?`; do
	echo "unmounting device '$i'"
	umount $i 2>/dev/null
done
 
echo "Make sd card success!"