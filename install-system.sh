#!/bin/bash

# This is just a temporary install script that will install xilinux into a folder
# recommended to run with root

KEY="davidovski https://xi.davidovski.xyz/repo/xi.pub"

R=$1

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

xi sync

xi -nyl --root . install $(ls /var/lib/xipkg/packages/core)
xi -nyl --root . keyimport $KEY
# chroot into the system to install xipkg and any postinstall scripts
xi -nyl --root . install xipkg

cd bin
ln -s bash sh

cd ../..

mkdir -p $R/var/lib/xipkg/
cp -r /var/lib/xipkg/packages $R/var/lib/xipkg
cp -r /var/lib/xipkg/keychain $R/var/lib/xipkg

# Autoconfiguring some things like network

echo "xilinux" > $R/etc/hostname

cat > $R/etc/resolv.conf << "EOF"
nameserver 80.80.80.80
nameserver 80.80.81.81
EOF

