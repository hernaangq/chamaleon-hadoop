#!/bin/bash

# Usage: ./run_gen.sh <Exponent_K> <Output_Folder>
# Example: ./run_gen.sh 20 output-16mb

K=$1
OUT=$2

if [ -z "$K" ]; then
    echo "Usage: ./run_gen.sh <K> <OUTPUT_DIR>"
    exit 1
fi

# Clean previous output if it exists
rm -rf $OUT
hdfs dfs -rm -r $OUT

echo "Starting Spark Generation (Sort) for K=$K..."

# Submit to Spark Cluster
# --master spark://tiny-node:7077 points to your Tiny Node manager
# --class is the Java Entry point
$SPARK_HOME/bin/spark-submit \
  --class edu.iit.cs553.SparkVault \
  --master spark://tiny-node:7077 \
  --deploy-mode client \
  --driver-memory 2G \
  --executor-memory 2G \
  target/spark-vault-1.0-SNAPSHOT.jar \
  -a gen \
  -k $K \
  -f $OUT