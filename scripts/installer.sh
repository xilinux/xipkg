#!/bin/sh

. /usr/lib/xitui.sh
. /usr/lib/glyphs.sh
. /usr/lib/colors.sh

logfile="installer.log"
default_packages="base linux xipkg dracut grub mksh sudo neofetch vim tzdata"
additional_services="networkmanager xorg iwd"

list_disks () {
    lsblk -r | while read -r line; do
        set - $line
        [ "$6" = "disk" ] && {
            printf '"/dev/%s (%s)" ' $1 $4
        }
    done
}

list_partitions () {
    ls $1*
    echo "none"
}

partition_disk () {
    t_msg "Partitioning $1..."
    export EFI_PART=$11
    export SYS_PART=$12
    export SWAP_PART=none
    echo "
    unit: sectors
    sector-size: 512

    type=ef, start=2048, size=210000
    type=83
    " | sfdisk $1 >$logfile &&
    t_msg "Partitioned $1!"
}

partition_disks () {
    eval "t_radio 'Select install disk' $(list_disks)"
    local selected=$(echo $T_RESULT | cut -d' ' -f1)

    t_yesno "${BLUE}Auto-partition $selected disk?\n${RED}(Warning: existing data will be overwritten)" &&  {
        partition_disk $selected || return 1
    } || {
        cfdisk $selected && {
            t_radio 'Select primary system partition' $(list_partitions $selected)
            export SYS_PART=$T_RESULT

            t_radio 'Select efi system partition' $(list_partitions $selected)
            export EFI_PART=$T_RESULT

            t_radio 'Select swap partition' $(list_partitions $selected)
            export SWAP_PART=$T_RESULT
        }
    }
}

format_disks () {
    t_msg "Formatting partitions...
${TABCHAR}System Partition
${TABCHAR}EFI Partition
"


    [ -b "$SYS_PART" ] && mkfs.ext4 $SYS_PART > $logfile
    t_msg "Formatting partitions...
${GREEN}${TABCHAR}System partition ${CHECKMARK} (ext4)
${TABCHAR}EFI Partition
"

    [ -b "$EFI_PART" ] && mkfs.fat -F 32 $EFI_PART > $logfile
    t_msg "Formatting partitions...
${GREEN}${TABCHAR}System partition ${CHECKMARK} (ext4)
${GREEN}${TABCHAR}EFI Partition ${CHECKMARK} (fat32)
"

    [ -b "$SWAP_PART" ] && mkswap $SWAP_PART > $logfile
    return 0
}

mount_disks () {
    t_msg "Mounting disks..."
    export sysroot=/xilinux.mnt
    export efi_mntpoint=/xilinux.mnt/boot/efi

    [ ! -f "$sysroot" ] && mkdir -p $sysroot

    [ -b "$SYS_PART" ] && {
        mount $SYS_PART $sysroot
    } ||  {
        t_prompt "${RED}No system partition is available!"
        return 1
    }

    [ -b "$EFI_PART" ] && {
        mkdir -p $efi_mntpoint
        mount $EFI_PART $efi_mntpoint
    }

    [ -b "$SWAP_PART" ] && swapon $SWAP_PART
    return 0
}

bootstrap_system () {
    t_msg "Creating directories..."
    xi -vy -r $sysroot bootstrap >> $logfile
}

install_base () {
    t_msg "Installing packages..."
    xi -vy -r $sysroot sync >> $logfile
    xi -vy -r $sysroot install $default_packages >> $logfile
}

copy_resolvconf () {
    cp /etc/resolv.conf $sysroot/etc/resolv.conf
}

sync_system () {
    t_msg "Syncing system..."
    xichroot $sysroot xi sync >> $logfile
}

generate_fstab () {
    t_msg "Generating fstab..."
    xichroot $sysroot genfstab -U / > $sysroot/etc/fstab
}

build_initramfs () {
    t_msg "Build initramfs"

    kernel_version=$(ls $SYSROOT/usr/lib/modules | tail -1)

    mkdir -p $sysroot/var/tmp
    xichroot $sysroot dracut --kver $kernel_version 2>&1 >> $logfile
}

install_grub () {
    t_yesno "Install grub?" && {
        target="x86_64-efi"
        opts="--target=$target --efi-directory=$efi_mntpoint"

        t_yesno "Install as removable system?" && opts="$opts --removable"

        t_msg "Installing grub for target $target..."
        xichrooot $sysroot grub-install $opts >> $logfile

        t_msg "Creating grub configuration..."
        xichrooot $sysroot grub-mkconfig -o /boot/grub/grub.cfg
    } || return 0
}

enter_password () {
    export password=""
    t_input_hidden "Enter Password:"
    passwd=$T_RESULT
    t_input_hidden "Confirm Password:"
    local cpasswd=$T_RESULT

    [ "$passwd" = "$cpasswd" ] || {
        t_prompt "Passwords do not match!"
        enter_password
    }

}

configure_users () {
    t_input_cmd "xichroot $sysroot passwd" "Enter root password"

    t_input "Enter username:"
    local username=$T_RESULT
    enter_password

    t_msg "Creating user..."
    xichroot $sysroot useradd -s /bin/mksh -m $username
    printf "$passwd\n$passwd\n" | xichroot $sysroot passwd $username

    t_yesno "Allow this user to use sudo?" && {
        echo "$username ALL=(ALL:ALL) ALL" >> $sysroot/etc/sudoers
    }

    t_yesno "Set a password for the root user?" && {
        enter_password
        printf "$passwd\n$passwd\n" | xichroot $sysroot passwd
    }

    return 0
}

fix_permissions () {
    xichroot $sysroot chmod 755 /
    xichroot $sysroot chmod 755 /usr
    xichroot $sysroot chmod 755 /usr/bin
    xichroot $sysroot chmod 755 /usr/lib
}

set_timezone () {
    zoneinfo="$sysroot/usr/share/zoneinfo"
    cp  $zoneinfo/$1 $sysroot/etc/localtime
    echo "$1" > /etc/timezone

    t_cls_ptrn
    t_prompt "Successfully set timezone!"
}

select_timezone () {
    t_clean_ptrn
    zoneinfo="$sysroot/usr/share/zoneinfo"
    selection=$1
    t_paged_radio "Select your timezone: $selection" $(ls "$zoneinfo/$selection") "more..."
    []
    selection="$selection/$T_RESULT"

    [ -f "$zoneinfo/$selection" ] && {

        t_yesno "Use $selection as your system timezone? " && {
            set_timezone $selection
        } || {
            select_timezone
        }
        return 0
    }

    [ -d "$zoneinfo/$selection" ] && {
        select_timezone $selection
    } || {
        t_prompt "The timezone you entered does not exist!"
        select_timezone
    }
}

install_additional () {
    t_check "Install and configure additional services: " $additional_services
    local services=$T_RESULT

    for service in $services; do
        service_$service
    done
}

service_networkmanager () {
    t_msg "Installing NetworkManager..."
    {
        xi -ly -r $sysroot install networkmanager 
        xichroot $sysroot rc-update add networkmanager
    } >> $logfile
}

service_iwd () {
    t_msg "Installing iwd..."
    {
        xi -ly -r $sysroot install iwd 
        xichroot $sysroot rc-update add iwd
    } >> $logfile
}

service_xorg () {
    t_msg "Installing xorg..."
    xi -r $sysroot install base-xorg base-fonts >> $logfile
    t_check "Select video drivers:" $(xi search xd86-video- | cut -f2 -d/)
    [ "${#T_RESULT}" != "0" ] && xi -r $sysroot install $T_RESULT
    t_prompt "Installed basic xorg functionality
TODO: preconfigured window managers, for now you need to configure them yourself"
}


umount_disks () {
    umount -R $sysroot
    [ -b "$SWAP_PART" ] && swapoff $SWAP_PART
    return 0
}

t_init
t_no_cur
checkroot 

steps="partition_disks
format_disks
mount_disks
bootstrap_system
install_base
copy_resolvconf
sync_system
generate_fstab
build_initramfs
configure_users
fix_permissions
select_timezone
install_additional
umount_disks
"

for step in $steps; do
    t_cls_ptrn
    $step 2>> $logfile || {
        t_prompt "${RED}An error occured!"
        t_clean
        exit 1
    }
done
t_prompt "Completed install!"

t_clean
