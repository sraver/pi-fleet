#!/bin/bash

set -e

source ifaces.cfg

nmcli device disconnect $wan
sudo killall openvpn 2>/dev/null
sudo ./fw.clear

