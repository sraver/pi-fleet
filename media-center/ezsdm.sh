#!/bin/bash

function errexit() {
    echo -e "$1"
    exit 1
}

[ $EUID -eq 0 ] && sudo="" || sudo="sudo"

img="$1"
[ "$img" == "" ] && errexit "? No IMG specified"

[ "$(type -t sdm)" == "" ] && errexit "? sdm is not installed"

# sdm wants full paths for the files it copies into the IMG
here="$(cd "$(dirname "$0")" && pwd)"

assets="$here/../assets"
[ -d $assets ] || errexit "? No assets directory"
[ -f $assets/authorized_keys ] || errexit "? No authorized_keys in $assets"

plugins_tmp=$(mktemp -t ".plugins.XXXXXX")
# A directory, so the generated file can be named exactly ".env": copyfile
# copies a file into a target *directory*, keeping its basename.
env_dir=$(mktemp -d -t ".env.XXXXXX")

new_user="watcher"
home="/home/$new_user"

hostname="mediabox"
timezone="Asia/Bangkok"

appdir="/opt/media-center"
data_root="/mnt/data"

# Container uid/gid. Must match $new_user, which sdm creates as the first
# non-system account, so 1000:1000.
puid=1000
pgid=1000

# --- .env baked into the image ------------------------------------------------
# Kept out of git (see .gitignore) and generated here so the image is ready to
# run with no manual editing.

(cat <<EOF
PUID=$puid
PGID=$pgid
TZ=$timezone
DATA_ROOT=$data_root

PROWLARR_PORT=9696
SONARR_PORT=8989
RADARR_PORT=7878
QBITTORRENT_PORT=8080
JELLYFIN_PORT=8096
QBITTORRENT_PEER_PORT=6881
EOF
    ) |bash -c "cat >|$env_dir/.env"

# --- sdm plugins --------------------------------------------------------------

(cat <<EOF

# Users
user:deluser=pi
user:adduser=$new_user|uid=$puid

mkdir:dir=$home/.ssh|chown=$new_user:$new_user|chmod=700
copyfile:from=$assets/authorized_keys|to=$home/.ssh|chown=$new_user:$new_user|chmod=600|mkdirif

# Packages
# gdisk provides sgdisk, used by prepare-disk.sh
apps:name=tools|apps=vim,htop,rsync,gdisk

# Pi things
disables:piwiz
L10n:host

# Docker engine + compose plugin from Docker's own apt repo
docker-install

# Mount point for the external SSD. Left empty and owned by root: if the disk
# is missing, bootstrap-data.sh refuses to start rather than filling the SD card.
mkdir:dir=$data_root|chown=root:root|chmod=755

# Stack definition
mkdir:dir=$appdir|chown=$new_user:$new_user|chmod=755
copyfile:from=$here/docker-compose.yml|to=$appdir|chown=$new_user:$new_user|chmod=644|mkdirif
copyfile:from=$here/bootstrap-data.sh|to=$appdir|chown=root:root|chmod=755|mkdirif
copyfile:from=$here/prepare-disk.sh|to=$appdir|chown=root:root|chmod=755|mkdirif
copyfile:from=$env_dir/.env|to=$appdir|chown=$new_user:$new_user|chmod=600|mkdirif

# Mount the media disk by ext4 label at boot
system:name=fstab|fstab=$here/fstab.media

# Let $new_user drive docker without sudo. post-install so the docker group
# created by docker-install in Phase 1 already exists.
runcommand:command=usermod -aG docker $new_user|runphase=post-install|stdout=/root/docker-group.out|stderr=/root/docker-group.error

# Services definition
copyfile:from=$here/media-center.service|to=/lib/systemd/system|chown=root:root|chmod=644

# Enable at FirstBoot, NOT during customize: the stack must not start until the
# fstab entry above is live, which only happens once FirstBoot has run. It comes
# up on the reboot that follows.
system:name=svc|service-enable-at-boot=media-center

EOF
    )  |bash -c "cat >|$plugins_tmp"

$sudo sdm --customize --hostname $hostname --plugin @$plugins_tmp --extend --xmb 2048 --regen-ssh-host-keys --reboot 10 $img

rm -f $plugins_tmp
rm -rf $env_dir
