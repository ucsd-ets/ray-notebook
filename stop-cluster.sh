#!/bin/bash

# Modify this script by copying it to your home directory
# *** be sure to remove the "exec" line below from your copy! ***
USERSCRIPT=$HOME/stop-cluster.sh
if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi

exec 2>>${HOME}/stop-cluster.log 1>&2

kubectl delete deployment deployment-ray-worker
kubectl delete service service-ray-cluster
