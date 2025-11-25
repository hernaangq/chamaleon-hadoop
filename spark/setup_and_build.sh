#!/bin/bash

# 1. Install Maven and Java (Required to build and run Java code)
echo "Installing Maven and Java 11..."
sudo apt-get update
sudo apt-get install -y maven openjdk-11-jdk

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Verify Java installation
echo "Java version:"
java -version

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

# 5. Check if SparkVault.java exists
if [ ! -f "src/main/java/edu/iit/cs553/SparkVault.java" ]; then
    echo "ERROR: SparkVault.java not found!"
    echo "Please place SparkVault.java in the current directory first."
    exit 1
fi

# 6. Fix the output format class reference
echo "Patching SparkVault.java..."
sed -i 's/org.apache.hadoop.mapred.lib.MultipleOutputs.class/org.apache.hadoop.mapred.SequenceFileOutputFormat.class/' src/main/java/edu/iit/cs553/SparkVault.java

# 7. Ensure pom.xml exists
if [ ! -f "pom.xml" ]; then
    echo "ERROR: pom.xml not found!"
    echo "Creating basic pom.xml..."
    cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>edu.iit.cs553</groupId>
    <artifactId>spark-vault</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <spark.version>3.5.0</spark.version>
        <hadoop.version>3.3.4</hadoop.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.apache.spark</groupId>
            <artifactId>spark-core_2.12</artifactId>
            <version>${spark.version}</version>
            <scope>provided</scope>
        </dependency>
        <dependency>
            <groupId>org.apache.hadoop</groupId>
            <artifactId>hadoop-client</artifactId>
            <version>${hadoop.version}</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
fi

# 8. Clean and Build the JAR
echo "Building SparkVault JAR..."
mvn clean package

# 9. Verify the build
if [ -f "target/spark-vault-1.0-SNAPSHOT.jar" ]; then
    echo ""
    echo "Build Complete!"
    echo "Your JAR is located at: target/spark-vault-1.0-SNAPSHOT.jar"
    echo ""
    echo "Checking JAR contents:"
    jar tf target/spark-vault-1.0-SNAPSHOT.jar | grep SparkVault
else
    echo "ERROR: Build failed! JAR not created."
    exit 1
fi

echo "Spark is installed at: ~/spark"
echo "Java is installed at: $JAVA_HOME"