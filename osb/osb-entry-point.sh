#!/bin/bash

set -x

echo "Current user:"
id
echo "Listing /share-data:"
ls -la /share-data
echo "Listing /share-data/osb:"
ls -la /share-data/osb

DEFAULT_ENDPOINT="test:9200"

# Parse some arguments
export RUN_ID="$RUN_ID"
export PROCEDURE="$OSB_PROCEDURE"
export PARAMS_FILE="$OSB_PARAMS"
export TEST_ENDPOINT=${ENDPOINT:-"${DEFAULT_ENDPOINT}"}
export WORKLOAD_REPO=${OSB_WORKLOADS_REPO}
echo "Workload repo: "
echo $WORKLOAD_REPO

export IS_LOCAL=1
if [ -n "$ENDPOINT" ]; then
  IS_LOCAL=0
fi

# Just sleep for a minute initially in order to let other containers come up healthily
if [ ${IS_LOCAL} = 1 ]; then
  sleep 30
fi

# Confirm access to metrics cluster
if [ ${IS_LOCAL} = 1 ]; then
  echo "Confirming access to metrics cluster..."
  curl metrics:9202
fi

# Confirm access to test cluster
echo "Confirming access to test cluster..."
curl ${TEST_ENDPOINT}

SHARED_PATH=/share-data
RESULTS_PATH=${SHARED_PATH}/results
OSB_PATH=${SHARED_PATH}/osb
STOP_PROCESS_PATH=${SHARED_PATH}/stop.txt

WORKLOAD_ARG=""
if [ ! -z "${WORKLOAD_REPO}" ] && [ "${WORKLOAD_REPO}" != "" ]; then
    # Clean up any existing repo
    rm -rf /opensearch-benchmark/osb_repo

    # Clone the repository
    echo "Cloning workload repository..."
    git clone ${WORKLOAD_REPO} /opensearch-benchmark/osb_repo

    if [ $? -eq 0 ]; then
        echo "Successfully cloned repository"
        WORKLOAD_ARG="--workload-path=/opensearch-benchmark/osb_repo/vectorsearch"
    else
        echo "Failed to clone repository"
        exit 1
    fi
fi


# Initialize OSB so benchmark.ini gets created and patch benchmark.ini
if [ ! -f "~/.benchmark/benchmark.ini" ]; then
  echo "Initializing OSB..."
  cp /benchmark.ini.patch /tmp/benchmark.ini.patch
  if [ ${IS_LOCAL} = 0 ]; then
    # Get rid of data store
    sed -i 's/\(datastore\.type\).*/\1 = in-memory/' /tmp/benchmark.ini.patch
    sed -i 's/\(datastore\.host\).*/\1 =/' /tmp/benchmark.ini.patch
    sed -i 's/\(datastore\.port\).*/\1 =/' /tmp/benchmark.ini.patch
    sed -i 's/\(datastore\.secure\).*/\1 =/' /tmp/benchmark.ini.patch
    sed -i 's/\(datastore\.user\).*/\1 =/' /tmp/benchmark.ini.patch
    sed -i 's/\(datastore\.password\).*/\1 =/' /tmp/benchmark.ini.patch
  fi

  if [ -n "$WORKLOAD_REPO" ]; then
      echo "" >> /tmp/benchmark.ini.patch
      echo "" >> /tmp/benchmark.ini.patch
 #     echo "[workloads]" >> /tmp/benchmark.ini.patch
 #     echo "custom.url=${WORKLOAD_REPO}" >> /tmp/benchmark.ini.patch
  fi

  mkdir -p -m 777 ~/.benchmark
  cp /tmp/benchmark.ini.patch ~/.benchmark/benchmark.ini
 # opensearch-benchmark execute-test ${WORKLOAD_ARG}
fi
cat ~/.benchmark/benchmark.ini
# Run OSB and write output to a particular file in results
echo "Running OSB..."
opensearch-benchmark execute-test ${WORKLOAD_ARG} \
    --target-hosts ${TEST_ENDPOINT} \
    --workload-params ${PARAMS_FILE} \
    --pipeline benchmark-only \
    --test-procedure=${PROCEDURE} \
    --kill-running-processes \
    --results-format=csv \
    --results-file=${RESULTS_PATH}/osb-results-${RUN_ID}.csv | tee /tmp/output.txt

cp /opensearch-benchmark/.benchmark/logs/benchmark.log ${OSB_PATH}/benchmark-${RUN_ID}.log

echo "Checking workload directory:"
ls -la /opensearch-benchmark/.benchmark/benchmarks/workloads/custom/vectorsearch/indices || echo "Directory doesn't exist"
ls -la /opensearch-benchmark/.benchmark/benchmarks/workloads/

#TODO: Make this configurable.
if [ ${IS_LOCAL} = 1 ]; then
  echo stop > ${STOP_PROCESS_PATH}
fi