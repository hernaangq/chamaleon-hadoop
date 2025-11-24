#!/bin/bash

# Set environment variables for Hadoop user

cat >> /home/hadoop/.bashrc << 'EOF'

# Hadoop Environment Variables
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HADOOP_HOME=/usr/local/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export JAVA_HOME=$(readlink -f /usr/bin/java | sed 's:/bin/java::')
export PATH=$PATH:$JAVA_HOME/bin

EOF

# Source it immediately for current session
su - hadoop -c "source /home/hadoop/.bashrc"