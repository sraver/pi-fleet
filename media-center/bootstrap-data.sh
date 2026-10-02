#!/bin/bash
#
# Runs as ExecStartPre of media-center.service, on every boot.
# Asserts the external disk is really mounted, then makes sure the directory
# tree exists and is owned by the container user.
#
# Guarding on mountpoint matters: without it, a missing disk would silently
# create /mnt/data/... on the SD card and the stack would happily fill it up.

set -euo pipefail

DATA_ROOT="${DATA_ROOT:-/mnt/data}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if ! mountpoint -q "$DATA_ROOT"; then
    echo "? $DATA_ROOT is not a mount point - is the SSD plugged in and labelled 'mediadata'?" >&2
    echo "  Check with: lsblk -f    Prepare a new disk with: prepare-disk.sh /dev/sdX" >&2
    exit 1
fi

mkdir -p \
    "$DATA_ROOT"/appdata/{prowlarr,sonarr,radarr,qbittorrent,jellyfin,jellyfin-cache} \
    "$DATA_ROOT"/downloads \
    "$DATA_ROOT"/media/{tv,movies}

# Only fix ownership where it's wrong; a blanket recursive chown over a full
# media library takes minutes and would delay every boot.
find "$DATA_ROOT" -maxdepth 2 \! -uid "$PUID" -exec chown "$PUID:$PGID" {} +

echo "* $DATA_ROOT ready"
