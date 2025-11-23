#!/bin/bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt install ufw -y
sudo apt-get install lxc -y
sudo lxd init --auto