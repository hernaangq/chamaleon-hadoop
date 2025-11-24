#!/bin/bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install openjdk-8-jdk -y
sudo apt-get install apt-transport-https -y
sudo apt-get install ca-certificates -y
sudo apt-get install build-essential -y
sudo apt-get install apt-utils -y
sudo apt-get install ssh -y

sudo apt-get install lxc -y
sudo lxd init --auto
sudo firewall-cmd --zone=trusted --add-interface=lxdbr0 --permanent
sudo firewall-cmd --reload
