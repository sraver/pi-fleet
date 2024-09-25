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

hostsfile="hostlist.txt"
[ -f $hostsfile ] || errexit "? No hostslist.txt"

plugins_tmp=$(mktemp -t ".plugins.XXXXXX")

new_user="sha"
home="/home/$new_user"

source ifaces.cfg

net="10.0.0"
router="${net}.1"
net_low_range="${net}.10"
net_high_range="${net}.100"
hostname="bouncer"
domain="lulz"
fqdn="${hostname}.${domain}"
dns="9.9.9.9"
timeserver="129.6.15.28"
lan_iface=$lan

ssid="myhsnet"
psk="11112222"

(cat <<EOF

# Users
user:deluser=pi
user:adduser=$new_user

mkdir:dir=$home/.ssh|chown=$new_user:$new_user|chmod=700
copyfile:from=$assets/authorized_keys|to=$home/.ssh|chown=$new_user:$new_user|chmod=600|mkdirif

# Packages
apps:name=tools|apps=vim,iptables,openvpn

# Pi things
disables:piwiz
L10n:host

# Set up Hotspot
hotspot:hsname=myhs|wifissid=$ssid|wifipassword=$psk|hsenable|type=routed|dhcpmode=none|wlanip=$router

copyfile:from=$assets/galaxy.nmconnection|to=/etc/NetworkManager/system-connections|chown=root:root|chmod=600|mkdirif

# Set up ndm/dnsmasq
ndm:dhcpserver=dnsmasq|dnsserver=dnsmasq|dobuild|doinstall|importnet=$hostsfile|dhcprange=$net_low_range,$net_high_range|domain=$domain|externaldns=$dns|gateway=$router|myip=$router|hostname=$hostname|dnsfqdn=$fqdn|mxfqdn=$fqdn|timeserver=$timeserver|netdev=$lan_iface|enablesvcs

# Copy helpers
copyfile:from=ifaces.cfg|to=$home|chown=$new_user:$new_user|chmod=600
copyfile:from=country_codes.txt|to=$home|chown=$new_user:$new_user|chmod=600
copyfile:from=connect.sh|to=$home|chown=$new_user:$new_user|chmod=700
copyfile:from=disconnect.sh|to=$home|chown=$new_user:$new_user|chmod=700
copyfile:from=iptables_w_vpn.sh|to=$home|chown=$new_user:$new_user|chmod=700
copyfile:from=iptables_wo_vpn.sh|to=$home|chown=$new_user:$new_user|chmod=700
copyfile:from=vpn.sh|to=$home|chown=$new_user:$new_user|chmod=700
copyfile:from=route.sh|to=$home|chown=$new_user:$new_user|chmod=700

# Copy VPN files
copydir:from=mullvad_files|to=$home

EOF
    )  |bash -c "cat >|$plugins_tmp"

$sudo sdm --customize --hostname $hostname --plugin @$plugins_tmp --extend --xmb 1024 --regen-ssh-host-keys --reboot 10 $img

rm $plugins_tmp


