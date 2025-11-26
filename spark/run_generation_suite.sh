#!/bin/bash

# ==============================================================================
# CS553 HW5 - Spark Generation Benchmark Suite
# ==============================================================================
# This script executes the GENERATION (Sort) tests for K=30, 31, 32.
# It creates the datasets in HDFS that are required for the search benchmarks.

# --- Configuration ---
MASTER="yarn" 
JAR_PATH="target/spark-vault-1.0-SNAPSHOT.jar"
CLASS_NAME="edu.iit.cs553.SparkVault"
HDFS_BASE_DIR="hdfs:///hw5"

# Ensure Spark is reachable
if [ -z "$SPARK_HOME" ]; then
    export SPARK_HOME=~/spark
    export PATH=$PATH:$SPARK_HOME/bin
fi

# Check for JAR file
if [ ! -f "$JAR_PATH" ]; then
    echo "❌ Error: JAR file not found at $JAR_PATH"
    echo "Please run './setup_and_build.sh' first."
    exit 1
fi

echo "=========================================================="
echo "      Starting Spark Generation (Sort) Benchmarks"
echo "=========================================================="
echo "Master: $MASTER"
echo "Target: HDFS ($HDFS_BASE_DIR)"
echo "=========================================================="
echo ""

# Function to run a single generation benchmark
run_gen_test() {
    local K=$1
    
    # Map K to readable size labels for filenames
    if [ "$K" -eq 30 ]; then SIZE="16GB"; fi
    if [ "$K" -eq 31 ]; then SIZE="32GB"; fi
    if [ "$K" -eq 32 ]; then SIZE="64GB"; fi

    local OUTPUT_DIR="$HDFS_BASE_DIR/data-${SIZE}"

    echo ">>> Running Generation: K=$K ($SIZE)"
    echo "    Output: $OUTPUT_DIR"
    
    # Clean up previous run if exists
    hdfs dfs -rm -r -f $OUTPUT_DIR > /dev/null 2>&1

    # We use 'time' to capture Wall Clock Time for the report
    time spark-submit \
        --class $CLASS_NAME \
        --master $MASTER \
        --deploy-mode client \
        --driver-memory 4G \
        --executor-memory 2G \
        --num-executors 8 \
        $JAR_PATH \
        -a gen \
        -k $K \
        -f $OUTPUT_DIR
    
    if [ $? -eq 0 ]; then
        echo "✅ Generation K=$K ($SIZE) Completed."
    else
        echo "❌ Generation K=$K ($SIZE) FAILED."
        exit 1 # Stop immediately on failure so we don't waste time
    fi
    echo "----------------------------------------------------------"
    echo ""
}

# --- Execute Benchmarks ---

# 1. K=30 (16GB)
run_gen_test 30

# 2. K=31 (32GB)
run_gen_test 31

# 3. K=32 (64GB) - MONITOR THIS ONE WITH HTOP/DSTAT!
run_gen_test 32

echo "=========================================================="
echo "      All Generation Benchmarks Finished."
echo "=========================================================="