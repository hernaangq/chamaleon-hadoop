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

mkdirs(){
    rm -rf /tmp/*
    for dir in scripts ssh apps conf; do mkdir -p /tmp/$dir; done
}

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

createScripts(){
cat > /tmp/scripts/setup-user.sh << EOF
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export PATH="\$PATH:\$JAVA_HOME/bin"
useradd -m -s /bin/bash -G sudo hadoop
echo "hadoop:hadoop" | chpasswd
sudo su -c "rm -f /home/hadoop/.ssh/id_rsa /home/hadoop/.ssh/id_rsa.pub" hadoop
sudo su -c "ssh-keygen -q -t rsa -f /home/hadoop/.ssh/id_rsa -N ''" hadoop
sudo su -c "cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys" hadoop
sudo su -c "mkdir -p /home/hadoop/hdfs/{namenode,datanode}" hadoop
sudo su -c "chown -R hadoop:hadoop /home/hadoop" hadoop
EOF

cat > /tmp/scripts/set_env.sh << EOF
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
HADOOP_HOME=/usr/local/hadoop
HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
HADOOP_MAPRED_HOME=\$HADOOP_HOME
HADOOP_COMMON_HOME=\$HADOOP_HOME
HADOOP_HDFS_HOME=\$HADOOP_HOME
YARN_HOME=\$HADOOP_HOME
PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
bash /home/hadoop/initial_setup.sh
EOF

cat > /tmp/scripts/source_container.sh << EOF
sudo su -c "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" hadoop
sudo su -c "export HADOOP_HOME=/usr/local/hadoop" hadoop
sudo su -c "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop" hadoop
sudo su -c "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_COMMON_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_HDFS_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export YARN_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" hadoop

cat /root/set_env.sh >> /home/hadoop/.bashrc 
chown -R hadoop:hadoop /home/hadoop/

sudo su -c "source /home/hadoop/.bashrc" hadoop
EOF

cat > /tmp/scripts/source_baremetal.sh << EOF
sudo su -c "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" hadoop
sudo su -c "export HADOOP_HOME=/usr/local/hadoop" hadoop
sudo su -c "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop " hadoop
sudo su -c "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_COMMON_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_HDFS_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export YARN_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" hadoop

cat /tmp/scripts/set_env.sh >> /home/hadoop/.bashrc 
chown -R hadoop:hadoop /home/hadoop/

sudo su -c "source /home/hadoop/.bashrc" hadoop
EOF

cat > /tmp/scripts/start-hadoop.sh << EOF
sudo su -c "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" hadoop
sudo su -c "export HADOOP_HOME=/usr/local/hadoop" hadoop
sudo su -c "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop " hadoop
sudo su -c "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_COMMON_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_HDFS_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export YARN_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" hadoop
EOF

echo 'sed -i "s/export JAVA_HOME=\${JAVA_HOME}/export JAVA_HOME=\/usr\/lib\/jvm\/java-8-openjdk-amd64/g" /usr/local/hadoop/etc/hadoop/hadoop-env.sh' > /tmp/scripts/update-java-home.sh
echo 'chown -R hadoop:hadoop /usr/local/hadoop' >> /tmp/scripts/update-java-home.sh
echo 'echo "Executing: hadoop namenode -format: "' > /tmp/scripts/initial_setup.sh
echo 'sleep 2' >> /tmp/scripts/initial_setup.sh
echo 'hadoop namenode -format' >> /tmp/scripts/initial_setup.sh
echo 'echo "Executing: start-dfs.sh"' >> /tmp/scripts/initial_setup.sh
echo 'sleep 2' >> /tmp/scripts/initial_setup.sh
echo 'start-dfs.sh' >> /tmp/scripts/initial_setup.sh
echo 'echo "Executing: start-yarn.sh"' >> /tmp/scripts/initial_setup.sh
echo 'sleep 2' >> /tmp/scripts/initial_setup.sh
echo 'start-yarn.sh' >> /tmp/scripts/initial_setup.sh
echo "sed -i 's/bash \/home\/hadoop\/initial_setup.sh//g' /home/hadoop/.bashrc" >> /tmp/scripts/initial_setup.sh

}

# ---------- CREATES FILE OF HOSTS FOR HADOOP CONFIG ----------
generateHostsFile() {

    SLAVES=("$@")   # all container names passed into the function

    OUTPUT="/tmp/scripts/hosts"

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

    OUTPUT="/tmp/scripts/ssh.sh"

    MASTER_IP=$(hostname -I | awk '{print $1}')

    {
        echo "#!/bin/bash"
        echo "sudo -u hadoop ssh -o 'StrictHostKeyChecking no' -o ConnectTimeout=2 $MASTER_IP 'echo ok' >/dev/null 2>&1"

        for slave in "${SLAVES[@]}"; do
            SLAVE_IP=$(lxc list "$slave" -c 4 --format csv | cut -d ' ' -f 1)
            echo "sudo -u hadoop ssh -o 'StrictHostKeyChecking no' -o ConnectTimeout=2 $SLAVE_IP 'echo ok' >/dev/null 2>&1"
        done
    } > "$OUTPUT"

}

# ---------- CREATES A SCRIPT FOR MASTER AND SLAVES LIST ----------
generateHadoopConfigFiles() {
    
    SLAVES=("$@")   # all container names passed into the function

    CONF_DIR="/tmp/conf"

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

    wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz -O /tmp/apps/hadoop-3.3.6.tar.gz
    sleep 2

    #Push to own fs (baremetal)
    rm -rf /usr/local/hadoop /usr/local/hadoop-3.3.6 /usr/local/hadoop-3.3.6.tar.gz
    cp /tmp/apps/hadoop-3.3.6.tar.gz /usr/local/hadoop-3.3.6.tar.gz
    tar -xf /usr/local/hadoop-3.3.6.tar.gz -C /usr/local/
    mv /usr/local/hadoop-3.3.6 /usr/local/hadoop
    mkdir -p /usr/local/hadoop/logs
    #chown -R hadoop:hadoop /usr/local/hadoop
    
    #Push to containers
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- rm -rf /usr/local/hadoop /usr/local/hadoop-3.3.6 /usr/local/hadoop-3.3.6.tar.gz
        lxc file push /tmp/apps/hadoop-3.3.6.tar.gz $i/usr/local/hadoop-3.3.6.tar.gz
        lxc exec $i -- tar -xf /usr/local/hadoop-3.3.6.tar.gz -C /usr/local/
        lxc exec $i -- mv /usr/local/hadoop-3.3.6 /usr/local/hadoop
        lxc exec $i -- mkdir -p /usr/local/hadoop/logs
        #lxc exec $i -- chown -R hadoop:hadoop /usr/local/hadoop
    done
}

# ---------- MOVES NECESSARY SCRIPTS FROM HOST TO SLAVE VM ----------
moveScripts(){

    SLAVES=("$@")   # all container names passed into the function

    cp /tmp/scripts/hosts /etc/hosts
    cp /tmp/scripts/setup-user.sh /root/setup-user.sh
    cp /tmp/scripts/set_env.sh /root/set_env.sh
    cp /tmp/scripts/source_baremetal.sh /root/source.sh
    cp /tmp/scripts/ssh.sh /root/ssh.sh
    cp /tmp/scripts/start-hadoop.sh /root/start-hadoop.sh
    cp /tmp/scripts/update-java-home.sh /root/update-java-home.sh

    for i in "${SLAVES[@]}"; do
        lxc file push /tmp/scripts/hosts $i/etc/hosts
        lxc file push /tmp/scripts/setup-user.sh $i/root/setup-user.sh
        lxc file push /tmp/scripts/set_env.sh $i/root/set_env.sh
        lxc file push /tmp/scripts/source_container.sh $i/root/source.sh
        lxc file push /tmp/scripts/ssh.sh $i/root/ssh.sh
        lxc file push /tmp/scripts/update-java-home.sh $i/root/update-java-home.sh
    done

}

generateHadoopConfig(){

cat >  /tmp/conf/core-site.xml << EOF
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://hadoop-master:8020/</value>
  </property>
</configuration>
EOF

cat > /tmp/conf/hdfs-site.xml << EOF
<configuration>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:$HDFS_PATH/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:$HDFS_PATH/datanode</value>
  </property>\n  <property>\n    <name>dfs.replication</name>\n    <value>2</value>\n  </property>\n  <property>\n    <name>dfs.block.size</name>\n    <value>134217728</value>\n  </property>\n  <property>
    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
    <value>false</value>
  </property>
</configuration>
EOF

cat > /tmp/conf/mapred-site.xml << EOF
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>mapreduce.jobhistory.address</name>
    <value>hadoop-master:10020</value>
  </property>
  <property>
    <name>mapreduce.jobhistory.webapp.address</name>
    <value>hadoop-master:19888</value>
  </property>
  <property>
    <name>mapred.child.java.opts</name>
    <value>-Djava.security.egd=file:/dev/../dev/urandom</value>
  </property>
</configuration>
EOF

cat > /tmp/conf/yarn-site.xml << EOF
<configuration>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>hadoop-master</value>
  </property>
  <property>
    <name>yarn.resourcemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.nodemanager.remote-app-log-dir</name>
    <value>hdfs://hadoop-master:8020/var/log/hadoop-yarn/apps</value>
  </property>
</configuration>
EOF
}

# ---------- MOVES NECESSARY CONFIG FILES FROM HOST TO SLAVE VM ----------
moveHadoopConfs(){

    SLAVES=("$@")   # all container names passed into the function
    
    cp /tmp/conf/masters /usr/local/hadoop/etc/hadoop/masters
    cp /tmp/conf/slaves /usr/local/hadoop/etc/hadoop/slaves
    cp /tmp/conf/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml
    cp /tmp/conf/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml
    cp /tmp/conf/mapred-site.xml /usr/local/hadoop/etc/hadoop/mapred-site.xml
    cp /tmp/conf/yarn-site.xml /usr/local/hadoop/etc/hadoop/yarn-site.xml

    for i in "${SLAVES[@]}"; do
        lxc file push /tmp/conf/masters $i/usr/local/hadoop/etc/hadoop/masters
        lxc file push /tmp/conf/slaves $i/usr/local/hadoop/etc/hadoop/slaves
        lxc file push /tmp/conf/core-site.xml $i/usr/local/hadoop/etc/hadoop/core-site.xml
        lxc file push /tmp/conf/hdfs-site.xml $i/usr/local/hadoop/etc/hadoop/hdfs-site.xml
        lxc file push /tmp/conf/mapred-site.xml $i/usr/local/hadoop/etc/hadoop/mapred-site.xml
        lxc file push /tmp/conf/yarn-site.xml $i/usr/local/hadoop/etc/hadoop/yarn-site.xml
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
    
    chmod +x /root/setup-user.sh
    /root/setup-user.sh
    
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- bash /root/setup-user.sh
    done
}

setupPasswordlessSSH(){

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
}

ensureSSH(){
    SLAVES=("$@")   # all container names passed into the function

    /root/ssh.sh

    for i in "${SLAVES[@]}"; do
        lxc exec $i -- bash /root/ssh.sh
    done
}

moveInitialScript(){
    cp /tmp/scripts/initial_setup.sh /home/hadoop/initial_setup.sh
    chown hadoop:hadoop /home/hadoop/initial_setup.sh
}

executeScripts(){

    SLAVES=("$@")
    
    # Execute source.sh on master
    bash /root/source.sh
    chown -R hadoop:hadoop /usr/local/hadoop

    # Execute source.sh on all slaves
    for i in "${SLAVES[@]}"; do
        lxc exec $i -- bash /root/source.sh
        lxc exec $i -- chown -R hadoop:hadoop /usr/local/hadoop
    done
}

startHadoop(){
    # Run as hadoop user
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 

    chmod +x /root/start-hadoop.sh
    /root/start-hadoop.sh
    #su - hadoop -c "hdfs namenode -format -force"
    #su - hadoop -c "start-dfs.sh"
    #su - hadoop -c "start-yarn.sh"
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
            launch_instance "hadoop-slave-1" large
            launch_instance "hadoop-slave-2" tiny
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
mkdirs
run_config
#installUpdates "${NODES[@]}"
getHostInfo "${NODES[@]}"
createScripts
generateHostsFile "${NODES[@]}"
generateSSHPrimingScript "${NODES[@]}"
generateHadoopConfigFiles "${NODES[@]}"
getHadoop "${NODES[@]}"
moveScripts "${NODES[@]}"
generateHadoopConfig
moveHadoopConfs "${NODES[@]}"
configureSSH "${NODES[@]}"
setupUsers "${NODES[@]}"
setupPasswordlessSSH "${NODES[@]}"
ensureSSH "${NODES[@]}"
moveInitialScript
executeScripts "${NODES[@]}"
startHadoop
printInstructions
