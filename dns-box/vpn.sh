#!/bin/bash

folder="mullvad_files"

readarray list < <(ls -1 ${folder}/*all.conf | cut -d'/' -f2 | cut -d'_' -f2 | sort)

for country in ${list[@]}
do
    country_name=$(grep "$country:" country_codes.txt | cut -d':' -f2)
    echo -e "$country : $country_name"
done

read -p $'\nCountry: ' country

cd $folder

sudo openvpn --config "mullvad_${country}_all.conf" --daemon
