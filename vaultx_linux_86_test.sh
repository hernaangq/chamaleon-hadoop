#!/bin/bash
set -ex

INSTANCE_NAME="vault-instance"
VAULT_BINARY="./vaultx_linux_x86"

run_scenario() {
    local dataset_gb=$1
    local ram_mib=$2
    local ram_gib=$((ram_mib / 1024))
    local instance_id=$3
    local k_val=$4
    local cpu_cores=$5
    local disk_size=$6
    local vm_ram=$7


    local current_instance_name="${INSTANCE_NAME}-${instance_id}"
    local data_file_name="data-${dataset_gb}GB.bin"
    local temp_file_name="data-${dataset_gb}GB.tmp"
    local vault_command="/root/vaultx_linux_x86 -t 32 -i 1 -m ${ram_mib} -k ${k_val} -g ${temp_file_name} -f ${data_file_name}"

    echo "Running Scenario: ${dataset_gb}GB Dataset with ${ram_gib}GiB RAM"

    lxc launch ubuntu:24.04 ${current_instance_name} -c limits.cpu=${cpu_cores} -c limits.memory=${vm_ram}GiB -d root,size=${disk_size}GiB
    
    sleep 5

    lxc exec ${current_instance_name} -- bash -c "
        apt-get update &&
        apt-get upgrade -y
    "
    lxc file push ${VAULT_BINARY} ${current_instance_name}/root/vaultx_linux_x86

    echo "Ejecutando vaultx en la instancia ${current_instance_name}"
    lxc exec ${current_instance_name} -- bash -c "${vault_command}"

    echo "Execution complete for ${current_instance_name}"

    # 4. Detener y eliminar la instancia
    lxc stop ${current_instance_name}
    lxc delete ${current_instance_name}
    
    echo "Instance ${current_instance_name} deleted"
}

# Parameters: dataset_gb, ram_mib (vault), instance_id, k-value, cpu_cores, disk_size, vm_ram

# Scenario 1: 16GB dataset, 2GB RAM - small
run_scenario 16 2048 1 30 4 30 4 
# Scenario 2: 32GB dataset, 2GB RAM - small
run_scenario 32 2048 2 31 4 30 4
# Scenario 3: 16GB dataset, 16GB RAM -large
run_scenario 16 16384 3 30 32 240 32
# Scenario 4: 32GB dataset, 16GB RAM -large
run_scenario 32 16384 4 31 32 240 32
# Scenario 5: 64GB dataset, 16GB RAM -large
run_scenario 32 16384 5 32 32 240 32


