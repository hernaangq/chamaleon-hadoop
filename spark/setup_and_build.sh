#!/bin/bash

# 1. Install Maven (Required to build Java code)
echo "Installing Maven..."
sudo apt-get update
sudo apt-get install -y maven

# 2. Install Spark if not present
if [ ! -d "$HOME/spark" ]; then
    echo "Spark not found. Installing Spark 3.5.0..."
    cd ~
    wget https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
    tar -xzf spark-3.5.0-bin-hadoop3.tgz
    mv spark-3.5.0-bin-hadoop3 spark
    rm spark-3.5.0-bin-hadoop3.tgz
    echo "Spark installed at ~/spark"
    cd -
else
    echo "Spark already installed at ~/spark"
fi

# 3. Create Directory Structure
mkdir -p src/main/java/edu/iit/cs553

# 4. Move SparkVault.java to the correct folder
# (Assuming you created the file in the current directory)
if [ -f "SparkVault.java" ]; then
    mv SparkVault.java src/main/java/edu/iit/cs553/
fi

# 5. Fix the output format class reference
echo "Patching SparkVault.java..."
sed -i 's/org.apache.hadoop.mapred.lib.MultipleOutputs.class/org.apache.hadoop.mapred.SequenceFileOutputFormat.class/' src/main/java/edu/iit/cs553/SparkVault.java

# 6. Build the JAR
echo "Building SparkVault JAR..."
mvn clean package

echo "Build Complete!"
echo "Your JAR is located at: target/spark-vault-1.0-SNAPSHOT.jar"
echo "Spark is installed at: ~/spark"