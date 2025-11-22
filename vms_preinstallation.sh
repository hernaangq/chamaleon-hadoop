# 1. Initialize LXD (Accept all defaults by pressing Enter for every question)
sudo lxd init

# 2. Modify Firewall rules to allow the VMs to talk to the network
sudo ufw allow in on lxdbr0
sudo ufw route allow in on lxdbr0
sudo ufw route allow out on lxdbr0