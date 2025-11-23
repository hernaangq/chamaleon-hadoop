#!/bin/bash
HADOOP_ENV="/usr/local/hadoop/etc/hadoop/hadoop-env.sh"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME|" "$HADOOP_ENV"
chown -R hadoop:hadoop /usr/local/hadoop