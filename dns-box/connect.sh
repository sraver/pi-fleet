#!/bin/bash

set -e

function errexit() {
    echo -e $'\nERROR: '$1
    exit 1
}

source ifaces.cfg

iface=$wan

IFS=$'\n'

# Print networks list

readarray list < <(nmcli dev wifi list ifname $iface | tail -n +2)

for key in ${!list[@]}
do
    echo -n "$key - ${list[$key]}"
done

# Ask network

read -p $'\nNetwork to connect: ' option

total=$(( ${#list[@]} - 1 ))

[ $option -gt $total ] && errexit "Wrong network number"

ssid=$(echo ${list[$option]} | awk '{print $2}')

# Ask password

read -p $'\nPassword for '"\"${ssid}\": " password

# Connect

connect_cmd="sudo nmcli device wifi connect $ssid ifname $iface"

[ "$password" == "" ] || connect_cmd="${connect_cmd} password ${password}"

connect_cmd="${connect_cmd} ipv4.ignore-auto-dns yes"

echo # new line

eval $connect_cmd

# Launch routing setup script

./route.sh
