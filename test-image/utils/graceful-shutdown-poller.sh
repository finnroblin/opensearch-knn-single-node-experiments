#!/bin/bash
# If the stop.txt file is set, this will gracefully shutdown opensearch so that profiles can properly be dumped
# on exit
SET_STOP_PROCESS_FILE=/share-data/stop.txt
OS_PID=$1
while true; do
  if [ -f ${SET_STOP_PROCESS_FILE} ]; then
    rm ${SET_STOP_PROCESS_FILE}
    echo "OS process is finished, but not shutting down!"
    echo $OS_PID
  fi
  sleep 1
done
