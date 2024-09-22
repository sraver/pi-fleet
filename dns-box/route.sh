#!/bin/bash

# Ask for VPN

read -p $'\nUse VPN (Y/n): ' use_vpn

# Enable forwarding

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

if [ "$use_vpn" == "n" ]; then
  echo "Without VPN..."
	sudo killall openvpn 2>/dev/null
	sudo ./iptables_wo_vpn.sh
else
  echo "With VPN..."
	./vpn.sh
	while [[ $(ifconfig | grep tun | wc -l) -eq 0 ]]; do
	  echo "Waiting for tunnel..."
	  sleep 0.3
  done
  echo "Connected"
	sudo ./iptables_w_vpn.sh
fi
