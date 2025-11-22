#!/bin/bash

# ==============================================================================
# CS553 HW5 - KVM/Libvirt Cluster Provisioner (Ubuntu 24.04)
# ==============================================================================

# --- Configuration ---
# Directory to store VM disks (Must have >250GB space)
IMG_DIR="/var/lib/libvirt/images"
# Ubuntu 24.04 Cloud Image URL
ISO_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
BASE_IMG="$IMG_DIR/ubuntu-24.04-base.qcow2"

# [cite_start]VM Specs [cite: 187]
# Tiny (Manager)
TINY_CPU=4
TINY_RAM=4096
TINY_DISK="10G"

# Large (Benchmark)
LARGE_CPU=32
LARGE_RAM=32768
LARGE_DISK="240G"

# Small (Worker)
SMALL_CPU=4
SMALL_RAM=4096
SMALL_DISK="30G"
NUM_SMALL_NODES=8

# --- Cloud-Init Configuration (Auto-Login) ---
# This sets the user 'ubuntu' with password 'ubuntu' and enables SSH
cat > user-data <<EOF
#cloud-config
password: ubuntu
chpasswd: { expire: False }
ssh_pwauth: True
hostname: localhost
ssh_authorized_keys:
  - $(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")
EOF

# ==============================================================================
# Helper Functions
# ==============================================================================

setup_base_image() {
    if [ ! -f "$BASE_IMG" ]; then
        echo ">>> Downloading Ubuntu 24.04 Cloud Image..."
        sudo wget -O "$BASE_IMG" "$ISO_URL"
        sudo chmod 644 "$BASE_IMG"
    else
        echo ">>> Base image already exists. Skipping download."
    fi
}

ensure_network() {
    echo ">>> Checking default network..."
    
    # Check if default network exists
    if ! sudo virsh net-list --all | grep -q "default"; then
        echo "  - Creating default network..."
        sudo virsh net-define /usr/share/libvirt/networks/default.xml
    fi
    
    # Start network if not active
    if ! sudo virsh net-list | grep -q "default.*active"; then
        echo "  - Starting default network..."
        sudo virsh net-start default
    fi
    
    # Set to autostart
    sudo virsh net-autostart default > /dev/null 2>&1
    echo "  - Default network is active."
}

cleanup_vm() {
    local name=$1
    echo "Checking for existing VM: $name..."
    if sudo virsh list --all | grep -q "$name"; then
        echo "  - Destroying $name..."
        sudo virsh destroy $name > /dev/null 2>&1
        echo "  - Undefining $name..."
        sudo virsh undefine $name > /dev/null 2>&1
    fi
    
    # Clean up disk files
    if [ -f "$IMG_DIR/$name.qcow2" ]; then
        echo "  - Removing disk $IMG_DIR/$name.qcow2..."
        sudo rm -f "$IMG_DIR/$name.qcow2"
    fi
    if [ -f "$IMG_DIR/$name-cidata.iso" ]; then
        sudo rm -f "$IMG_DIR/$name-cidata.iso"
    fi
}

launch_vm() {
    local name=$1
    local cpu=$2
    local ram=$3
    local disk_size=$4
    
    echo "------------------------------------------------"
    echo "Launching VM: $name"
    echo "Specs: $cpu vCPU, $ram MB RAM, $disk_size Disk"
    
    # 1. Create a fresh disk from the base image
    echo "  - Creating disk image..."
    sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMG" "$IMG_DIR/$name.qcow2" $disk_size
    
    # 2. Generate Cloud-Init ISO (Sets password/network)
    echo "  - Generating cloud-init configuration..."
    # Update hostname in user-data for this specific VM
    sed "s/hostname: localhost/hostname: $name/" user-data > "user-data-$name"
    sudo cloud-localds "$IMG_DIR/$name-cidata.iso" "user-data-$name"
    rm "user-data-$name"

    # 3. Install/Boot
    echo "  - Booting via virt-install..."
    sudo virt-install \
        --name "$name" \
        --memory "$ram" \
        --vcpus "$cpu" \
        --disk "path=$IMG_DIR/$name.qcow2,device=disk,bus=virtio" \
        --disk "path=$IMG_DIR/$name-cidata.iso,device=cdrom" \
        --os-variant ubuntu22.04 \
        --network network=default,model=virtio \
        --graphics none \
        --noautoconsole \
        --import

    echo "  - VM $name started."
}

# ==============================================================================
# Main Execution
# ==============================================================================

# Ensure we have KVM
if ! command -v virsh &> /dev/null; then
    echo "Error: KVM/Libvirt not installed."
    echo "Run: sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst cloud-image-utils"
    exit 1
fi

setup_base_image

ensure_network

echo "=================================================="
echo "      CS553 HW5 - KVM Cluster Manager"
echo "=================================================="
echo "1) Setup Env1 (1 Large + 1 Tiny)"
echo "2) Setup Env2 (8 Small + 1 Tiny)"
echo "3) Cleanup ALL"
echo ""
read -p "Select option: " choice

case $choice in
    1)
        echo ">>> Provisioning Env1 (Benchmarking)..."
        # Cleanup potential Env2
        cleanup_vm "large-node" # Clean self if exists
        for i in $(seq 1 $NUM_SMALL_NODES); do cleanup_vm "small-node-$i"; done
        
        # Launch
        cleanup_vm "tiny-node"
        launch_vm "tiny-node" $TINY_CPU $TINY_RAM $TINY_DISK
        launch_vm "large-node" $LARGE_CPU $LARGE_RAM $LARGE_DISK
        ;;
        
    2)
        echo ">>> Provisioning Env2 (Distributed Cluster)..."
        # Cleanup potential Env1
        cleanup_vm "large-node"
        
        # Launch Tiny
        cleanup_vm "tiny-node"
        launch_vm "tiny-node" $TINY_CPU $TINY_RAM $TINY_DISK
        
        # Launch Smalls
        for i in $(seq 1 $NUM_SMALL_NODES); do
            cleanup_vm "small-node-$i"
            launch_vm "small-node-$i" $SMALL_CPU $SMALL_RAM $SMALL_DISK
        done
        ;;
        
    3)
        echo ">>> Cleaning up everything..."
        cleanup_vm "tiny-node"
        cleanup_vm "large-node"
        for i in $(seq 1 $NUM_SMALL_NODES); do cleanup_vm "small-node-$i"; done
        ;;
esac

echo ""
echo "Provisioning complete."
echo "You can verify VMs with: sudo virsh list"
echo "IP Addresses will be assigned by virbr0 (NAT)."
echo "Login User: ubuntu"
echo "Login Pass: ubuntu"