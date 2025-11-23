#!/bin/bash
# run_local.sh

# 1. compile the code (if you haven't yet)
if [ ! -f "target/spark-vault-1.0-SNAPSHOT.jar" ]; then
    echo "Compiling code..."
    mvn clean package
fi

# 2. Set Parameters for a SMALL test
K=16                   # 2^16 = 65,536 records (Tiny!)
OUTPUT_DIR="local-out" # Local folder, not HDFS

# 3. Clean up previous run (Standard Linux command, not hdfs dfs -rm)
rm -rf $OUTPUT_DIR

echo "Running Spark in LOCAL Mode..."

# 4. Run Spark
# --master local[*]  -> Run locally using all CPUs
$SPARK_HOME/bin/spark-submit \
  --class edu.iit.cs553.SparkVault \
  --master local[*] \
  --driver-memory 2G \
  target/spark-vault-1.0-SNAPSHOT.jar \
  -a gen \
  -k $K \
  -f $OUTPUT_DIR

echo "Done! Check the '$OUTPUT_DIR' folder."