#!/bin/bash

# ==============================================================================
# CS553 HW5 - Cluster Environment Switcher (Env1 vs Env2)
# ==============================================================================

# --- Configuration Constants ---
OS_IMAGE="ubuntu:24.04"

# Tiny Instance (Used in both environments)
TINY_NAME="tiny-node"
TINY_CPU=4
TINY_RAM="4GiB"
TINY_DISK="10GiB"

# Env1: Large Instance
LARGE_NAME="large-node"
LARGE_CPU=32
LARGE_RAM="32GiB"
LARGE_DISK="240GiB"

# Env2: Small Instances
SMALL_PREFIX="small-node-"
SMALL_CPU=4
SMALL_RAM="4GiB"
SMALL_DISK="30GiB"
NUM_SMALL_NODES=8

# --- Helper Functions ---

# Check if LXD is ready
check_lxd() {
    if ! command -v lxc &> /dev/null; then
        echo "Error: LXD is not installed. Please run 'sudo lxd init' first."
        exit 1
    fi
}

# Wrapper to launch a VM with specific limits
launch_vm() {
    local name=$1
    local cpu=$2
    local ram=$3
    local disk=$4

    # Check if it already exists
    if sudo lxc list | grep -q "$name"; then
        echo "VM '$name' already exists. Skipping creation."
    else
        echo "Creating VM: $name ($cpu vCPU, $ram RAM, $disk Disk)..."
        sudo lxc launch $OS_IMAGE $name --vm \
            -c limits.cpu=$cpu \
            -c limits.memory=$ram \
            --device root,size=$disk
        
        # Add network device connected to lxdbr0
        echo "Configuring network for $name..."
        sudo lxc config device add $name eth0 nic nictype=bridged parent=lxdbr0
        
        # Wait for networking to come up before we assume it's ready
        echo "Waiting for $name to boot and get IP..."
        sleep 15
    fi
}

# Wrapper to delete a VM to free up disk space
delete_vm() {
    local name=$1
    if sudo lxc list | grep -q "$name"; then
        echo "Deleting '$name' to free up disk space..."
        sudo lxc delete $name --force
    fi
}

# --- Main Logic ---

check_lxd

echo "========================================================="
echo "      CS553 HW5 Environment Selector"
echo "========================================================="
echo "Disk Space Protection is ACTIVE."
echo "Selecting an environment will DELETE the VMs from the other"
echo "environment to prevent storage overflow (250GB limit)."
echo "========================================================="
echo ""
echo "1) Env1: 1 Large Instance + 1 Tiny Instance"
echo "   (Best for: Single-node Benchmarks)"
echo ""
echo "2) Env2: 8 Small Instances + 1 Tiny Instance"
echo "   (Best for: Distributed Hadoop/Spark Experiments)"
echo ""
echo "3) Clean All (Delete everything)"
echo ""
read -p "Select Environment (1, 2, or 3): " choice

case $choice in
    1)
        echo ""
        echo ">>> Setting up Env1 (Large + Tiny)..."
        
        # 1. Clean up Env2 (Small nodes) to free space
        echo "Step 1: Cleaning up Env2 nodes..."
        for i in $(seq 1 $NUM_SMALL_NODES); do
            delete_vm "${SMALL_PREFIX}${i}"
        done

        # 2. Ensure Tiny Node exists
        echo "Step 2: Provisioning Manager..."
        launch_vm $TINY_NAME $TINY_CPU $TINY_RAM $TINY_DISK

        # 3. Create Large Node
        echo "Step 3: Provisioning Large Node..."
        launch_vm $LARGE_NAME $LARGE_CPU $LARGE_RAM $LARGE_DISK
        ;;

    2)
        echo ""
        echo ">>> Setting up Env2 (8 Small + Tiny)..."

        # 1. Clean up Env1 (Large node) to free space
        echo "Step 1: Cleaning up Env1 nodes..."
        delete_vm $LARGE_NAME

        # 2. Ensure Tiny Node exists
        echo "Step 2: Provisioning Manager..."
        launch_vm $TINY_NAME $TINY_CPU $TINY_RAM $TINY_DISK

        # 3. Create Small Cluster
        echo "Step 3: Provisioning $NUM_SMALL_NODES Worker Nodes..."
        for i in $(seq 1 $NUM_SMALL_NODES); do
            launch_vm "${SMALL_PREFIX}${i}" $SMALL_CPU $SMALL_RAM $SMALL_DISK
        done
        ;;

    3)
        echo ">>> Cleaning up ALL VMs..."
        delete_vm $TINY_NAME
        delete_vm $LARGE_NAME
        for i in $(seq 1 $NUM_SMALL_NODES); do
            delete_vm "${SMALL_PREFIX}${i}"
        done
        ;;
    *)
        echo "Invalid selection."
        exit 1
        ;;
esac

echo ""
echo ">>> Setup Complete."
echo "Run 'sudo lxc list' to see your active VMs."