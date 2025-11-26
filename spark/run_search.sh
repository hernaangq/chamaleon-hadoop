#!/bin/bash

# Usage: ./run_search.sh <Input_Folder> <Difficulty>
# Example: ./run_search.sh output-16mb 4

IN=$1
DIFF=$2
JAR_PATH="$(pwd)/target/spark-vault-1.0-SNAPSHOT.jar"
SPARK_SUBMIT="$HOME/spark/bin/spark-submit"

if [ -z "$DIFF" ]; then
    echo "Usage: ./run_search.sh <INPUT_DIR> <DIFFICULTY>"
    exit 1
fi

# Fix: Set Hadoop config directory so Spark can communicate with YARN
export HADOOP_CONF_DIR=~/hadoop/etc/hadoop

LOG_FILE="log_search_$(basename $IN)_${DIFF}.txt"

echo "===================================================================="
echo "Starting Spark Search on $IN with Difficulty $DIFF..."
echo "Log: $LOG_FILE"
echo "===================================================================="

# Run Spark Job with timing
{ time $SPARK_SUBMIT \
  --class edu.iit.cs553.SparkVault \
  --master yarn \
  --deploy-mode client \
  --driver-memory 2G \
  --executor-memory 2G \
  $JAR_PATH \
  -a search \
  -f $IN \
  -q $DIFF \
  -s 1000 ; } 2>&1 | tee $LOG_FILE

echo ""
echo "Finished Search. Check $LOG_FILE for details."