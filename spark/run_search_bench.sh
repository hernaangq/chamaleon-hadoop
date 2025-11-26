#!/bin/bash

# ==============================================================================
# CS553 HW5 - Spark Search Benchmark Suite
# ==============================================================================
# This script executes the search tests for K=30, 31, 32 with difficulty 3 and 4.
# It assumes data generation for these K values has already been completed.

# --- Configuration ---
# Hardcoded to use YARN based on your setup.
# Change to 'local[*]' if testing locally without a cluster.
MASTER="yarn" 
JAR_PATH="target/spark-vault-1.0-SNAPSHOT.jar"
CLASS_NAME="edu.iit.cs553.SparkVault"
HDFS_BASE_DIR="hdfs:///hw5"
NUM_SEARCHES=1000

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
echo "      Starting Spark Search Benchmarks"
echo "=========================================================="
echo "Master: $MASTER"
echo "Searches per run: $NUM_SEARCHES"
echo "Data Location: $HDFS_BASE_DIR"
echo "=========================================================="
echo ""

# Function to run a single benchmark
run_search_test() {
    local K=$1
    local DIFFICULTY=$2
    local INPUT_DIR="$HDFS_BASE_DIR/data-${K}GB"

    # For K=30 (16GB), K=31 (32GB), K=32 (64GB) mapping
    if [ "$K" -eq 30 ]; then SIZE="16GB"; INPUT_DIR="$HDFS_BASE_DIR/data-16GB"; fi
    if [ "$K" -eq 31 ]; then SIZE="32GB"; INPUT_DIR="$HDFS_BASE_DIR/data-32GB"; fi
    if [ "$K" -eq 32 ]; then SIZE="64GB"; INPUT_DIR="$HDFS_BASE_DIR/data-64GB"; fi

    echo ">>> Running Search: K=$K ($SIZE), Difficulty=$DIFFICULTY"
    
    # We use 'time' to capture the total execution duration from the shell perspective
    # The Spark app will also print its own internal timing.
    spark-submit \
        --class $CLASS_NAME \
        --deploy-mode client \
        --driver-memory 4G \
        --executor-memory 2G \
        --num-executors 8 \
        $JAR_PATH \
        -a search \
        -f $INPUT_DIR \
        -q $DIFFICULTY \
        -s $NUM_SEARCHES
    
    if [ $? -eq 0 ]; then
        echo "✅ Test K=$K Diff=$DIFFICULTY Completed."
    else
        echo "❌ Test K=$K Diff=$DIFFICULTY FAILED."
    fi
    echo "----------------------------------------------------------"
    echo ""
}

# --- Execute Benchmarks ---

# 1. K=30 (16GB)
run_search_test 30 3
run_search_test 30 4

# 2. K=31 (32GB)
run_search_test 31 3
run_search_test 31 4

# 3. K=32 (64GB)
run_search_test 32 3
run_search_test 32 4

echo "=========================================================="
echo "      All Benchmarks Finished."
echo "=========================================================="