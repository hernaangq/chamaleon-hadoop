#!/bin/bash

#TODO: validar java home en el server
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
HADOOP_HOME=/usr/local/hadoop
HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
HADOOP_MAPRED_HOME=\$HADOOP_HOME
HADOOP_COMMON_HOME=\$HADOOP_HOME
HADOOP_HDFS_HOME=\$HADOOP_HOME
YARN_HOME=\$HADOOP_HOME
PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
bash /home/hadoop/initial_setup.sh