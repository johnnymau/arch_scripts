#########################################################
# Init

localectl set-keymap pt-latin9
timedatectl set-ntp true

#########################################################
# Create Partitions

# 1st Disk 
parted -s /dev/sda mktable gpt
parted -s /dev/sda mkpart primary 1MiB 2MiB
parted -s /dev/disk set 1 bios_grub on
parted -s /dev/sda mkpart primary fat32 2MiB 514MiB
parted -s /dev/sda set 2 boot on
parted -s /dev/sda mkpart primary btrfs 514MiB 100%

# 2nd Disk
parted -s /dev/sdb mktable gpt
parted -s /dev/sdb mkpart primary linux-swap 1MiB 4001MiB
parted -s /dev/sdb mkpart primary btrfs 40001MiB 50%

#########################################################
# Format Partitions

mkfs.vfat dev/sda2 # 1st Disk
mkfs.btrfs -L SYSTEM /dev/sda3 # 1st Disk
mkfs.btrfs -L DATA /dev/sdb2 # 2nd Disk
mkswap -L SWAP /dev/sdb1 #2nd disk

#########################################################
# Create Subvolumes

# 1st Disk
mount /dev/sda3 /mnt/

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@/opt
mkdir /mnt/@/var
btrfs subvolume create /mnt/@/var/cache
btrfs subvolume create /mnt/@/var/abs
btrfs subvolume create /mnt/@/var/tmp
btrfs subvolume create /mnt/@/srv

btrfs subvolume create /mnt/@snapshots

umount /mnt/

# 2nd Disk
mount /dev/sdb2 /mnt

btrfs subvolume create /mnt/@home
mkdir /mnt/@home/johnny
btrfs subvolume create /mnt/@home/johnny/Dropbox
btrfs subvolume create /mnt/@home/johnny/.steam
btrfs subvolume create /mnt/@cadence 

btrfs subvolume create /mnt/@vm

umount /mnt/

#########################################################
# Mount Partitions/Subvolumes

# ssd  commit=300,space_cache,ssd_spread
# data autodefrag,compress=lzo,commit=300,space_cache
# vm autodefrag,nodatacow,commit=300,space_cache

# 1st Disk
mkdir /mnt/.snapshots

mount -o rw,noatime,commit=300,space_cache,ssd_spread,subvol=@ /dev/sda3 /mnt/
mount -o rw,noatime,commit=300,space_cache,ssd_spread,subvol=@snapshots /dev/sda3 /mnt/.snapshots

mount /dev/sda2 /mnt/boot/efi 

# 2nd Disk
mkdir /mnt/home /mnt/opt /mnt/opt/cadence /mnt/srv /mnt/srv/vm

mount -o rw,noatime,autodefrag,commit=300,space_cache,subvol=@home /dev/sdb2 /mnt/home
mount -o rw,noatime,autodefrag,commit=300,space_cache,subvol=@cadence /dev/sdb2 /mnt/opt/cadence
mount -o rw,noatime,autodefrag,commit=300,space_cache,subvol=@vm /dev/sdb2 /mnt/srv/vm

swapon -d /dev/sdb1

#########################################################
# Setup Mirror

pacman -Syyu --noconfirm   
pacman -S reflector --noconfirm
reflector --country 'United Kingdom' --age 12 --protocol http --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syyu --noconfirm

#########################################################
# 

pacstrap /mnt base base-devel btrfs-progs grub grub-bios intel-ucode

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

# set time
ln -sf /usr/share/zoneinfo/Europe/Lisbon /etc/localtime

hwclock -systohc

# set locale
sed -i -e 's/#en_US\.UTF-8 UTF-8/en_US\.UTF-8 UTF-8/' /etc/locale.gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

locale-gen

# set hostname
hostnamectl set-hostname LAPTOP
echo "127.0.1.1 LAPTOP.localdomain LAPTOP" >> /etc/hosts

# set mkinitcpio
mkinitcpio -p linux