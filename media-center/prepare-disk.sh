#!/bin/bash
#
# ONE-TIME disk preparation, run ON THE PI. Formats the external drive ext4 and
# labels it "mediadata" so the fstab entry in the image picks it up.
#
# DESTRUCTIVE: this erases the target device.
#
#   sudo ./prepare-disk.sh /dev/sda

set -euo pipefail

function errexit() {
    echo -e "$1" >&2
    exit 1
}

LABEL="mediadata"
dev="${1:-}"

[ "$dev" == "" ] && errexit "? No device specified\n  Usage: sudo $0 /dev/sdX\n\n$(lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT)"
[ $EUID -eq 0 ] || errexit "? Must run as root"
[ -b "$dev" ] || errexit "? $dev is not a block device"

# Refuse to touch the disk we booted from
root_src="$(findmnt -no SOURCE / || true)"
root_disk="/dev/$(lsblk -no PKNAME "$root_src" 2>/dev/null || echo none)"
[ "$dev" == "$root_disk" ] && errexit "? $dev is the system disk. Refusing."

echo "About to ERASE $dev:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$dev"
echo
read -rp "Type the device path again to confirm: " confirm
[ "$confirm" == "$dev" ] || errexit "? Mismatch. Aborted."

# Unmount anything currently using it
umount "$dev"?* 2>/dev/null || true

echo "* Partitioning $dev"
sgdisk --zap-all "$dev" >/dev/null
sgdisk --new=1:0:0 --typecode=1:8300 --change-name=1:"$LABEL" "$dev" >/dev/null
partprobe "$dev"
sleep 2

part="${dev}1"
[ -b "${dev}p1" ] && part="${dev}p1"

echo "* Formatting $part as ext4, label=$LABEL"
# -m 0: don't reserve 5% for root, this is a data disk not a system disk
mkfs.ext4 -F -L "$LABEL" -m 0 "$part"

echo "* Mounting"
mkdir -p /mnt/data
mount /mnt/data 2>/dev/null || mount "$part" /mnt/data

echo
echo "* Done. $part is labelled '$LABEL' and mounted at /mnt/data"
echo "  Now start the stack:  sudo systemctl start media-center"
