#!/bin/bash

#TODO: validar java home en el server
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
export PATH="\$PATH:\$JAVA_HOME/bin"
useradd -m -s /bin/bash -G sudo hadoop
echo "hadoop\nhadoop" | passwd hadoop
sudo su -c "ssh-keygen -q -t rsa -f /home/hadoop/.ssh/id_rsa -N ''" hadoop
sudo su -c "cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys" hadoop
sudo su -c "mkdir -p /home/hadoop/hdfs/{namenode,datanode}" hadoop
sudo su -c "chown -R hadoop:hadoop /home/hadoop" hadoop