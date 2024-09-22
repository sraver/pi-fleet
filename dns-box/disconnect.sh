#!/bin/bash

set -e

source ifaces.cfg

sudo killall openvpn

nmcli device disconnect $wan
