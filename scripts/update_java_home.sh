#!/bin/bash
# chANGED: Path fixed from hadoop-3.3.6 to hadoop
HADOOP_ENV="/usr/local/hadoop/etc/hadoop/hadoop-env.sh"
JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"

sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME|" "$HADOOP_ENV"
chown -R hadoop:hadoop /usr/local/hadoop