#!/bin/bash

# Usage:
#   ./launch.sh 1   → 1 large + 1 tiny
#   ./launch.sh 2   → 8 small + 1 tiny
#   ./launch.sh 3   → custom example (you can extend it)

if [ -z "$1" ]; then
    echo "Usage: $0 <config-number>"
    exit 1
fi

CONFIG="$1"
UBUNTU_VERSION="24.04"

# ---------- INSTANCE TYPE DEFINITIONS ----------
# CPU, RAM, DISK limits for each VM type
define_limits() {
    case "$1" in
        tiny)
            CPU=4
            RAM="4GB"
            DISK="10GB"
            ;;
        small)
            CPU=4
            RAM="4GB"
            DISK="30GB"
            ;;
        large)
            CPU=32
            RAM="32GB"
            DISK="240GB"
            ;;
        *)
            echo "Unknown instance type: $1"
            exit 1
            ;;
    esac
}

# ---------- LAUNCH FUNCTION ----------
launch_instance() {
    NAME="$1"
    TYPE="$2"

    define_limits "$TYPE"

    echo "Launching $NAME ($TYPE) with $CPU CPUs, $RAM RAM, $DISK disk..."

    # Launch
    lxc launch ubuntu:$UBUNTU_VERSION "$NAME" -c limits.cpu="$CPU" -c limits.memory="$RAM"
    #sudo lxc-create -t ubuntu:$UBUNTU_VERSION -n "$NAME" -c limits.cpu="$CPU" -c limits.memory="$RAM"
    #lxc-start -d -n "$NAME"

    # Resize root disk
    #lxc config device set "$NAME" root size "$DISK"
}

# ---------- UPDATE VMS ----------
installUpdates() {
    HOSTS=("$@")  # list of hosts passed to function

    for host in "${HOSTS[@]}"; do
        echo "Updating $host ..."

        lxc exec "$host" -- bash -c "
            apt-get update &&
            apt-get upgrade -y &&
            apt-get install -y \
                openjdk-8-jdk \
                apt-transport-https \
                ca-certificates \
                build-essential \
                apt-utils \
                ssh \
                openssh-server \
                wget \
                curl
        "
    done
}

# ---------- CREATES ENV VARIABLES FOR VM IPS ----------
getHostInfo() {
    HOSTS=("$@")   # all container names passed into the function

    # Reset any old values
    unset HADOOP_MASTER_IP
    SLAVE_IPS=()

    for host in "${HOSTS[@]}"; do
        IP=$(lxc list "$host" -c 4 --format csv | cut -d ' ' -f 1)   # column 4 = IPv4
        if [[ "$host" == "hadoop-master" ]]; then
            export HADOOP_MASTER_IP="$IP"
        else
            SLAVE_IPS+=("$IP")
        fi
    done

    export HADOOP_MASTER_IP=$(hostname -I | awk '{print $1}')
    # Export each slave IP individually (optional)
    for i in "${!SLAVE_IPS[@]}"; do
        export HADOOP_SLAVE$((i+1))_IP="${SLAVE_IPS[$i]}"
    done

    export HDFS_PATH="/home/hadoop/hdfs"
}

# ---------- CREATES FILE OF HOSTS FOR HADOOP CONFIG ----------
generateHostsFile() {

    SLAVES=("$@")   # all container names passed into the function

    OUTPUT="./scripts/hosts"

    mkdir -p ./scripts

    # Bare-metal master IP
    MASTER_IP=$(hostname -I | awk '{print $1}')

    echo "127.0.0.1 localhost" > "$OUTPUT"
    echo "$MASTER_IP hadoop-master" >> "$OUTPUT"

    # For each slave that exists
    for slave in "${SLAVES[@]}"; do
        SLAVE_IP=$(lxc list "$slave" -c 4 --format csv | cut -d ' ' -f 1)
        echo "$SLAVE_IP $slave" >> "$OUTPUT"
    done
}

# ---------- CREATES A SCRIPT FOR SETTING KNOWN HOSTS WITHIN SLAVE VMS ----------
generateSSHPrimingScript() {

    SLAVES=("$@")   # all container names passed into the function

    OUTPUT="./scripts/ssh.sh"
    mkdir -p ./scripts

    MASTER_IP=$(hostname -I | awk '{print $1}')

    {
        echo "#!/bin/bash"
        echo "sudo -u hadoop ssh -o 'StrictHostKeyChecking no' -o ConnectTimeout=2 $MASTER_IP 'echo ok' >/dev/null 2>&1"

        for slave in "${SLAVES[@]}"; do
            SLAVE_IP=$(lxc list "$slave" -c 4 --format csv | cut -d ' ' -f 1)
            echo "sudo -u hadoop ssh -o 'StrictHostKeyChecking no' -o ConnectTimeout=2 $SLAVE_IP 'echo ok' >/dev/null 2>&1"
        done
    } > "$OUTPUT"

    chmod +x "$OUTPUT"
}

# ---------- CREATES A SCRIPT FOR MASTER AND SLAVES LIST ----------
generateHadoopConfigFiles() {
    
    SLAVES=("$@")   # all container names passed into the function

    CONF_DIR="./conf"
    mkdir -p "$CONF_DIR"

    # Master file
    echo "hadoop-master" > "$CONF_DIR/masters"

    # Slaves file
    > "$CONF_DIR/slaves"  # empty file first
    for i in "${!SLAVES[@]}"; do
        echo "hadoop-slave-$((i+1))" >> "$CONF_DIR/slaves"
    done
}

# ---------- FETCHES HADOOP FROM REPO AND MOVES IT TO SLAVES ----------
getHadoop(){

    SLAVES=("$@")

    mkdir -p /tmp/apps/ && wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz -O /tmp/apps/hadoop-3.3.6.tar.gz
    sleep 2

    #Push to own fs (baremetal)
    rm -rf /usr/local/hadoop /usr/local/hadoop-3.3.6 /usr/local/hadoop-3.3.6.tar.gz
    cp /tmp/apps/hadoop-3.3.6.tar.gz /usr/local/hadoop-3.3.6.tar.gz
    tar -xf /usr/local/hadoop-3.3.6.tar.gz -C /usr/local/
    mv /usr/local/hadoop-3.3.6 /usr/local/hadoop
    mkdir -p /usr/local/hadoop/logs
    chown -R hadoop:hadoop /usr/local/hadoop
    
    #Push to containers
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- rm -rf /usr/local/hadoop /usr/local/hadoop-3.3.6 /usr/local/hadoop-3.3.6.tar.gz
        lxc file push /tmp/apps/hadoop-3.3.6.tar.gz $i/usr/local/hadoop-3.3.6.tar.gz
        lxc exec $i -- tar -xf /usr/local/hadoop-3.3.6.tar.gz -C /usr/local/
        lxc exec $i -- mv /usr/local/hadoop-3.3.6 /usr/local/hadoop
        lxc exec $i -- mkdir -p /usr/local/hadoop/logs
        lxc exec $i -- chown -R hadoop:hadoop /usr/local/hadoop
    done
}

# ---------- MOVES NECESSARY SCRIPTS FROM HOST TO SLAVE VM ----------
moveScripts(){

    SLAVES=("$@")   # all container names passed into the function

    cp ./scripts/hosts /etc/hosts
    cp ./scripts/setup_user.sh /root/setup_user.sh
    cp ./scripts/set_env.sh /root/set_env.sh
    cp ./scripts/source.sh /root/source.sh
    cp ./scripts/ssh.sh /root/ssh.sh
    cp ./scripts/start_hadoop.sh /root/start_hadoop.sh
    cp ./scripts/update_java_home.sh /root/update_java_home.sh

    for i in "${SLAVES[@]}"; do
        lxc file push ./scripts/hosts $i/etc/hosts
        lxc file push ./scripts/setup_user.sh $i/root/setup-user.sh
        lxc file push ./scripts/set_env.sh $i/root/set_env.sh
        lxc file push ./scripts/source.sh $i/root/source.sh
        lxc file push ./scripts/ssh.sh $i/root/ssh.sh
        lxc file push ./scripts/update_java_home.sh $i/root/update_java_home.sh
    done

}

# ---------- MOVES NECESSARY CONFIG FILES FROM HOST TO SLAVE VM ----------
moveHadoopConfs(){

    SLAVES=("$@")   # all container names passed into the function
    
    cp ./conf/masters /usr/local/hadoop/etc/hadoop/masters
    cp ./conf/slaves /usr/local/hadoop/etc/hadoop/slaves
    cp ./conf/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml
    cp ./conf/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml
    cp ./conf/mapred-site.xml /usr/local/hadoop/etc/hadoop/mapred-site.xml
    cp ./conf/yarn-site.xml /usr/local/hadoop/etc/hadoop/yarn-site.xml

    for i in "${SLAVES[@]}"; do
        lxc file push ./conf/masters $i/usr/local/hadoop/etc/hadoop/masters
        lxc file push ./conf/slaves $i/usr/local/hadoop/etc/hadoop/slaves
        lxc file push ./conf/core-site.xml $i/usr/local/hadoop/etc/hadoop/core-site.xml
        lxc file push ./conf/hdfs-site.xml $i/usr/local/hadoop/etc/hadoop/hdfs-site.xml
        lxc file push ./conf/mapred-site.xml $i/usr/local/hadoop/etc/hadoop/mapred-site.xml
        lxc file push ./conf/yarn-site.xml $i/usr/local/hadoop/etc/hadoop/yarn-site.xml
    done

}

configureSSH(){

    SLAVES=("$@")   # all container names passed into the function

    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
    /etc/init.d/ssh restart

    for i in "${SLAVES[@]}"; do
        lxc exec $i -- sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        lxc exec $i -- /etc/init.d/ssh restart ;
    done
}


setupUsers(){
    SLAVES=("$@")
    
    useradd -m -p $(openssl passwd -1 hadoop) -s /bin/bash hadoop
    echo "hadoop:hadoop" | chpasswd
    
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- useradd -m -p $(openssl passwd -1 hadoop) -s /bin/bash hadoop
        lxc exec $i -- bash -c "echo 'hadoop:hadoop' | chpasswd"
    done
    
    # Set environment variables
    executeScripts "${SLAVES[@]}"
}

setupPasswordlessSSH(){

    mkdir -p /tmp/ssh/

    SLAVES=("$@")   # all container names passed into the function

    rm -f /tmp/authorized_keys
    touch /tmp/authorized_keys
    chmod 666 /tmp/authorized_keys

    cat /home/hadoop/.ssh/id_rsa.pub >> /tmp/authorized_keys

    for i in "${SLAVES[@]}"; do
        lxc file pull $i/home/hadoop/.ssh/id_rsa.pub /tmp/ssh/id_rsa1.pub
        cat /tmp/ssh/id_rsa1.pub >> /tmp/authorized_keys
        lxc file push /tmp/authorized_keys $i/home/hadoop/.ssh/authorized_keys
    done

    cp /tmp/authorized_keys /home/hadoop/.ssh/authorized_keys
    chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
}

ensureSSH(){
    SLAVES=("$@")   # all container names passed into the function

    scripts/ssh.sh

    for i in "${SLAVES[@]}"; do
        lxc exec $i -- bash /root/ssh.sh
    done
}

moveInitialScript(){
    cp ./scripts/initial_setup.sh /home/hadoop/initial_setup.sh
    chown hadoop:hadoop /home/hadoop/initial_setup.sh
}

executeScripts(){

    SLAVES=("$@")
    
    # Execute source.sh on master
    bash ./scripts/source.sh
    
    # Execute source.sh on all slaves
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- bash /root/source.sh
    done
}

startHadoop(){
    # Run as hadoop user
    su - hadoop -c "hdfs namenode -format -force"
    su - hadoop -c "start-dfs.sh"
    su - hadoop -c "start-yarn.sh"
}

printInstructions(){
echo "Deployment Done"
echo "---------------"
echo ""
echo "1. Access Master:"
echo " $ lxc exec hadoop-master bash"
echo ""
echo "2. Switch user to hadoop:"
echo " $ su hadoop"
echo ""
echo "With the inital login namenode will be formatted and hadoop"
echo "daemons will be started."
}


# ---------- CONFIGURATIONS ----------
run_config() {

    NODES=()

    case "$CONFIG" in

        1)
            # 1 large + 1 tiny
            #launch_instance "hadoop-slave-1" large
            #launch_instance "hadoop-slave-2" tiny
            NODES+=("hadoop-slave-1")
            NODES+=("hadoop-slave-2")
            ;;

        2)
            # 8 small + 1 tiny
            launch_instance "hadoop-slave-1" tiny
            NODES+=("hadoop-slave-1")

            for i in {2..9}; do
                launch_instance "hadoop-slave-$i" small
                NODES+=("hadoop-slave-$i")
            done
            ;;

        3)
            echo "Config 3 not defined — customize here."
            ;;

        *)
            echo "Unknown config number: $CONFIG"
            exit 1
            ;;
    esac
}




# ---------- RUN ----------
run_config
#installUpdates "${NODES[@]}"
getHostInfo "${NODES[@]}"
generateHostsFile "${NODES[@]}"
generateSSHPrimingScript "${NODES[@]}"
generateHadoopConfigFiles "${NODES[@]}"
getHadoop "${NODES[@]}"
moveScripts "${NODES[@]}"
moveHadoopConfs "${NODES[@]}"
configureSSH "${NODES[@]}"
setupUsers "${NODES[@]}"
setupPasswordlessSSH "${NODES[@]}"
ensureSSH "${NODES[@]}"
moveInitialScript
executeScripts "${NODES[@]}"
startHadoop
printInstructions
