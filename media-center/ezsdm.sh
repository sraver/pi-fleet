#!/bin/bash

function errexit() {
    echo -e "$1"
    exit 1
}

[ $EUID -eq 0 ] && sudo="" || sudo="sudo"

img="$1"
[ "$img" == "" ] && errexit "? No IMG specified"

[ "$(type -t sdm)" == "" ] && errexit "? sdm is not installed"

assets="../assets"
[ -d $assets ] || errexit "? No assets directory"

plugins_tmp=$(mktemp -t ".plugins.XXXXXX")

new_user="sha"

hostname="jukebox"
psk="11112222"

(cat <<EOF

# Users
user:deluser=pi
user:adduser=$new_user

mkdir:dir=/home/$new_user/.ssh|chown=$new_user:$new_user|chmod=700
copyfile:from=$assets/authorized_keys|to=/home/$new_user/.ssh|chown=$new_user:$new_user|chmod=600|mkdirif

# Packages
apps:name=tools|apps=vim,kodi21,qbittorrent-nox

# Pi things
disables:piwiz
L10n:host

# Set up Hotspot
hotspot:hsname=myhs|wifissid=$hostname|wifipassword=$psk|hsenable|type=routed|dhcpmode=nm

# Copy default connection
copyfile:from=$assets/galaxy.nmconnection|to=/etc/NetworkManager/system-connections|chown=root:root|chmod=600|mkdirif

# Copy services definition
copyfile:from=kodi.service|to=/lib/systemd/system|chown=root:root|chmod=644
# torrent

# Enable servies
system:service-enable=kodi
# torrent


EOF
    )  |bash -c "cat >|$plugins_tmp"

$sudo sdm --customize --hostname $hostname --plugin @$plugins_tmp --extend --xmb 1024 --regen-ssh-host-keys --reboot 10 $img

rm $plugins_tmp


