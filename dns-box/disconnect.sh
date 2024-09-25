#!/bin/bash

set -e

source ifaces.cfg

nmcli device disconnect $wan
sudo killall openvpn
sudo ./fw.stop

