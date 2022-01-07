#!/bin/bash

# This is just a temporary install script that will install xilinux into a folder
# recommended to run with root

KEY="davidovski https://xi.davidovski.xyz/repo/xi.pub"

XI_OPTS="-nyl"

R=$1

[ $# -eq 0 ] && echo "Please specify where you would like to instal the system" && exit 1

if [ -e $R ]; then
    printf "Remove existing system? [Y/n] "
    read response

    if [ "$response" != "n" ]; then
        rm -rf $R
        echo "removed $R"
    fi
fi
    

mkdir -p $R
mkdir -p $R/tmp
mkdir -p $R/dev
mkdir -p $R/sys
mkdir -p $R/run
mkdir -p $R/proc
mkdir -p $R/usr/bin
mkdir -p $R/usr/lib
mkdir -p $R/root

cd $R
ln -s usr/bin bin
ln -s usr/bin sbin
ln -s usr/bin usr/sbin

ln -s usr/lib lib
ln -s usr/lib lib64
ln -s usr/lib usr/lib64

ln -s usr/local usr

xi sync &&
xi $XI_OPTS --root . install $(ls /var/lib/xipkg/packages/core) &&
xi $XI_OPTS --root . keyimport $KEY &&
# chroot into the system to install xipkg and any postinstall scripts
xi $XI_OPTS --root . install xipkg &&

cd ../.. &&

echo "base system installed next to do:" &&
echo "    xichroot into system" &&
echo "    set hostname at /etc/hostname" &&
echo "    configure DNS at /etc/resolv.conf" &&
echo "    xi sync" &&
echo "    install any additional packages" &&
echo "    compile and install kernel" &&
echo "    configure and install grub" &&
echo "  * hope that the system works!" &&
echo "have fun!" &&
exit 0;

echo "something went wrong"
exit 0;


## leftover autoconfig scripts

mkdir -p $R/var/lib/xipkg/
cp -r /var/lib/xipkg/packages $R/var/lib/xipkg
cp -r /var/lib/xipkg/keychain $R/var/lib/xipkg

# Autoconfiguring some things like network

mkdir -p $R/etc
echo "xilinux" > $R/etc/hostname

cat > $R/etc/resolv.conf << "EOF"
nameserver 80.80.80.80
nameserver 80.80.81.81
EOF

