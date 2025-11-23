#!/bin/bash

# 1. Install Maven (Required to build Java code)
echo "Installing Maven..."
sudo apt-get update
sudo apt-get install -y maven

# 2. Create Directory Structure
mkdir -p src/main/java/edu/iit/cs553

# 3. Move SparkVault.java to the correct folder
# (Assuming you created the file in the current directory)
if [ -f "SparkVault.java" ]; then
    mv SparkVault.java src/main/java/edu/iit/cs553/
fi

# 4. Build the JAR
echo "Building SparkVault JAR..."
mvn clean package

echo "Build Complete!"
echo "Your JAR is located at: target/spark-vault-1.0-SNAPSHOT.jar"