#!/bin/bash

# Usage: ./run_batch.sh <mode>
# Modes:
#   1_small  : Runs 1 executor, 2GB RAM (Rows 1-3)
#   1_large  : Runs 1 executor, 16GB RAM (Rows 4-6)
#   8_small  : Runs 8 executors, 2GB RAM (Rows 7-9)

MODE=$1
JAR_PATH="$(pwd)/target/spark-vault-1.0-SNAPSHOT.jar"
SPARK_SUBMIT="$HOME/spark/bin/spark-submit"

if [ -z "$MODE" ]; then
    echo "Usage: ./run_batch.sh <1_small | 1_large | 8_small>"
    exit 1
fi

# Function to run a single experiment
run_experiment() {
    local K_VAL=$1
    local SIZE_LABEL=$2
    local NUM_EXEC=$3
    local EXEC_MEM=$4
    local LOG_FILE="log_${MODE}_${SIZE_LABEL}.txt"
    local HDFS_OUT="hdfs:///hw5/data-${SIZE_LABEL}"

    echo "===================================================================="
    echo "Running: $MODE | Dataset: $SIZE_LABEL (K=$K_VAL) | Log: $LOG_FILE"
    echo "Config: $NUM_EXEC Executors, $EXEC_MEM Memory"
    echo "===================================================================="

    # Clean up HDFS output
    hdfs dfs -rm -r -skipTrash $HDFS_OUT 2>/dev/null

    # Run Spark Job with timing
    # We use a block { } to time the entire command and pipe both stdout/stderr to tee
    { time $SPARK_SUBMIT \
        --class edu.iit.cs553.SparkVault \
        --master yarn \
        --deploy-mode client \
        --driver-memory 4G \
        --executor-memory $EXEC_MEM \
        --num-executors $NUM_EXEC \
        $JAR_PATH \
        -a gen \
        -k $K_VAL \
        -f $HDFS_OUT ; } 2>&1 | tee $LOG_FILE
    
    echo ""
    echo "Finished $SIZE_LABEL. Check $LOG_FILE for the 'real' time."
    echo ""
}

# Configuration Logic
case $MODE in
    "1_small")
        # 1 small instance (2GB RAM)
        # 16GB Dataset (K=30)
        run_experiment 30 "16GB" 1 "2G"
        # 32GB Dataset (K=31)
        run_experiment 31 "32GB" 1 "2G"
        # 64GB Dataset (K=32)
        run_experiment 32 "64GB" 1 "2G"
        ;;
    
    "1_large")
        # 1 large instance (16GB RAM)
        run_experiment 30 "16GB" 1 "16G"
        run_experiment 31 "32GB" 1 "16G"
        run_experiment 32 "64GB" 1 "16G"
        ;;

    "8_small")
        # 8 small instances (2GB RAM each)
        run_experiment 30 "16GB" 8 "2G"
        run_experiment 31 "32GB" 8 "2G"
        run_experiment 32 "64GB" 8 "2G"
        ;;

    *)
        echo "Invalid mode. Use: 1_small, 1_large, or 8_small"
        exit 1
        ;;
esac

echo "Batch execution complete."