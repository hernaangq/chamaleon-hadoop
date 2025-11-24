#!/bin/bash

# Set environment variables for Hadoop user

# First, check if already configured to avoid duplicates
if ! grep -q "HADOOP_HOME" /home/hadoop/.bashrc; then
    cat >> /home/hadoop/.bashrc << 'EOF'

# System PATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Java
export JAVA_HOME=$(readlink -f /usr/bin/java | sed 's:/bin/java::')
export PATH=$PATH:$JAVA_HOME/bin

# Hadoop Environment Variables
export HADOOP_HOME=/usr/local/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

EOF
fi

# Also set JAVA_HOME in hadoop-env.sh
JAVA_PATH=$(readlink -f /usr/bin/java | sed 's:/bin/java::')
sed -i "s|# export JAVA_HOME=|export JAVA_HOME=$JAVA_PATH|g" /usr/local/hadoop/etc/hadoop/hadoop-env.sh

chown hadoop:hadoop /home/hadoop/.bashrc