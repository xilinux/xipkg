#!/bin/sh

default_packages="base linux-libre xipkg dracut grub bash"
additional_packages="doas neofetch vim networkmanager"
default_key="davidovski https://xi.davidovski.xyz/keychain/xi.pub"

XIPKG="/usr/bin/xi"
XIFLAGS="-ylu"
TMPDIR=/tmp
SYSROOT=$1

umask 0022

[ ! -e $XIPKG ] && {
    git clone https://xi.davidovski.xyz/git/xiutils.git $TMPDIR/xiutils
    make && make install

    git clone https://xi.davidovski.xyz/git/xipkg.git $TMPDIR/xipkg
    make && make install
}

echo "Please make sure that you have correctly formatted any partitions and mounted them as desired under $SYSROOT"

[ $# -eq 0 ] && echo "Please specify where you would like to instal the system" && exit 1

[ -e $SYSROOT ] && {
    printf "Remove existing system at $SYSROOT? [Y/n] "
    read response
    [ "$response" != "n" ] && rm -rf $SYSROOT && echo "removed $SYSROOT"
}

$XIPKG $XIFLAGS sync
mkdir -p $SYSROOT
$XIPKG $XIFLAGS -r $SYSROOT bootstrap 
mkdir -p $SYSROOT
$XIPKG $XIFLAGS -r $SYSROOT install $default_packages
$XIPKG $XIFLAGS -r $SYSROOT keyimport $default_key

configuring_users () {
    echo "Setting root password: "
    xichroot $SYSROOT passwd 

    echo
    echo "Creating user"
    read -p "Enter username: " username
    xichroot $SYSROOT useradd -s /bin/bash -m $username
    xichroot $SYSROOT passwd $username
}

configuring_system () {
    read -p "Enter system hostname: " hostname

    echo $hostname > $SYSROOT/etc/hostname

    cat > $SYSROOT/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.local $hostname
EOF
}

configuring_nameservers () {
    echo "Configuring nameservers..."

    cat > $SYSROOT/etc/resolv.conf << EOF
nameserver 80.80.80.80
EOF
}

generating_fstab () {
    echo "Generating fstab..."
    xichroot $SYSROOT genfstab -U / > $SYSROOT/etc/fstab
}

building_initramfs () {
    echo "Building initramfs..."
    kernel_version=$(ls $SYSROOT/usr/lib/modules | tail -1)
    xichroot $SYSROOT mkdir /var/tmp
    xichroot $SYSROOT dracut --kver $kernel_version 2>$TMPDIR/dracut.log > $TMPDIR/dracut.log
}

installing_bootloader () {
    read -p "Install Grub? [y]" r
    [ "$r" != "n" ] && {
        opts="--target=x86_64-efi"
    
        xichroot $SYSROOT lsblk
        read -p "Enter efi directory: " efi_part
        opts="$opts --efi-directory=$efi_part"

        read -p "Removable system? [y]" r
        [ "$r" != "n" ] && {
            opts="$opts --removable"
        }

        xichroot $SYSROOT grub-install $opts
        xichroot $SYSROOT grub-mkconfig -o /boot/grub/grub.cfg
    }
}

fixing_permissions () {
    xichroot $SYSROOT chmod 755 /
    xichroot $SYSROOT chmod 755 /usr
    xichroot $SYSROOT chmod 755 /usr/bin
    xichroot $SYSROOT chmod 755 /usr/lib
}

downloading_additional_packages () {
    echo "Syncing repos..."
    xichroot $SYSROOT xi sync
    echo "Downloading additional packages..."
    xi -r $SYSROOT $XIFLAGS install $additional_packages
}

steps="
configuring_nameservers
generating_fstab
building_initramfs
configuring_system
installing_bootloader
configuring_users
fixing_permissions
downloading_additional_packages
"

len=$(echo "$steps" | wc -l)
i=0

echo "Press [return] to enter configuration"
read response

for step in $steps; do
    i=$((i+1))
    clear
    hbar -t -T "$(echo $step | sed "s/_/ /g")" $i $len
    $step
done

echo "Installation finished!"
