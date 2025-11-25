#!/bin/bash

# Usage: ./run_search.sh <Input_Folder> <Difficulty>
# Example: ./run_search.sh output-16mb 4

IN=$1
DIFF=$2

if [ -z "$DIFF" ]; then
    echo "Usage: ./run_search.sh <INPUT_DIR> <DIFFICULTY>"
    exit 1
fi

echo "Starting Spark Search on $IN with Difficulty $DIFF..."

$SPARK_HOME/bin/spark-submit \
  --class edu.iit.cs553.SparkVault \
  --master spark://tiny-node:7077 \
  --deploy-mode client \
  --driver-memory 2G \
  --executor-memory 2G \
  target/spark-vault-1.0-SNAPSHOT.jar \
  -a search \
  -f $IN \
  -q $DIFF \
  -s 1000