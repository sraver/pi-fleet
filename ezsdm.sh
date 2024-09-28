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
home="/home/$new_user"

router="10.1.0.1"
hostname="bouncer"

ssid="myhsnet"
psk="11112222"

(cat <<EOF

# Users
user:deluser=pi
user:adduser=$new_user

mkdir:dir=$home/.ssh|chown=$new_user:$new_user|chmod=700
copyfile:from=$assets/authorized_keys|to=$home/.ssh|chown=$new_user:$new_user|chmod=600|mkdirif

# Packages
apps:name=tools|apps=vim

# Pi things
disables:piwiz
L10n:host

# Set up Hotspot
hotspot:hsname=myhs|wifissid=$ssid|wifipassword=$psk|hsenable|type=routed|dhcpmode=none|wlanip=$router

# Copy default connection
copyfile:from=$assets/galaxy.nmconnection|to=/etc/NetworkManager/system-connections|chown=root:root|chmod=600|mkdirif

EOF
    )  |bash -c "cat >|$plugins_tmp"

$sudo sdm --customize --hostname $hostname --plugin @$plugins_tmp --extend --xmb 1024 --regen-ssh-host-keys --reboot 10 $img

rm $plugins_tmp


