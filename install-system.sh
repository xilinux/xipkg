#!/bin/bash

# This is just a temporary install script that will install xilinux into a folder
# recommended to run with root

R=$1

mkdir -p $R
mkdir -p $R/tmp
mkdir -p $R/dev
mkdir -p $R/sys
mkdir -p $R/proc
mkdir -p $R/usr/bin
mkdir -p $R/usr/lib

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
xi -nyl --root . install xipkg