#!/bin/bash

#TODO: validar java home en el server
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export PATH="\$PATH:\$JAVA_HOME/bin"
/usr/sbin/useradd -m -s /bin/bash -G sudo hadoop
echo "hadoop:hadoop" | /usr/sbin/chpasswd
/usr/bin/sudo su -c "rm -f /home/hadoop/.ssh/id_rsa /home/hadoop/.ssh/id_rsa.pub" hadoop
/usr/bin/sudo su -c "ssh-keygen -q -t rsa -f /home/hadoop/.ssh/id_rsa -N ''" hadoop
/usr/bin/sudo su -c "cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys" hadoop
/usr/bin/sudo su -c "mkdir -p /home/hadoop/hdfs/{namenode,datanode}" hadoop
/usr/bin/sudo su -c "chown -R hadoop:hadoop /home/hadoop" hadoop