#!/bin/bash


PWD=`pwd`

FILE_PATH=$PWD"/binary/"

FILE_UBOOT="u-boot.imx"

# ²ÎÊý¼ì²é
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <sd device>"
    exit 1
fi

DRIVE=$1

echo "Buring the $FILE_UBOOT to sdcard $DRIVE"
if [ -e $FILE_PATH$FILE_UBOOT ]
then
	dd if=$FILE_PATH$FILE_UBOOT of=${DRIVE} bs=1K seek=1 conv=fsync
fi

echo ""
echo "Syncing...."
echo ""
sync
sync

echo "Install u-boot to sd card success!"