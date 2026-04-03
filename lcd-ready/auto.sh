#!/bin/bash
#
# Simple script to use sdm with plugins
# Edit the text inside the EOF/EOF as appropriate for your configuration
# ** Suggestion: Copy this file to somewhere in your path and edit your copy
#    (~/bin is a good location)


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

(cat <<EOF

user:deluser=pi
user:adduser=$new_user|password=$new_user

mkdir:dir=/home/$new_user/.ssh|chown=$new_user:$new_user|chmod=700
copyfile:from=$assets/authorized_keys|to=/home/$new_user/.ssh|chown=$new_user:$new_user|chmod=600|mkdirif

apps:name=tools|apps=git,vim

hotspot:config=$assets/hotspot.cfg

disables:piwiz
L10n:host

EOF
    ) | bash -c "cat >|$plugins_tmp"

$sudo sdm --customize --plugin @$plugins_tmp --regen-ssh-host-keys --reboot 10 $img

rm $plugins_tmp

