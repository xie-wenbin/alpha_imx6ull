# alpha_imx6ull
1.uboot 仓库

imx6ull_uboot_4.1.15 

2.kernel 仓库

imx6ull_kernel_4.1.15

## 制作sd启动卡
1.先使用命令 `df -h` 查看插入的sd是否能正确识别。

2.执行命令 `./mksdcard.sh` , 按提示进行即可。

## 烧录u-boot至sd卡
执行命令 `./install_u-boot.sh /dev/sdx` x为b/c/d等

## 制作sd烧录卡
`将sd卡中的镜像、内核、文件系统等烧录至emmc或nand中`

// todo
