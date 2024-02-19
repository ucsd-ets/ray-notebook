#!/bin/bash

# Modify this script by copying it to your home directory
# *** be sure to remove the "exec" line below from your copy! ***
USERSCRIPT=$HOME/start-cluster.sh
if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi

exec 2>>$HOME/ray-head.log 1>&2

# Datahub exposes limits/requests as floating point, Ray wants int
MY_CPU_REQUEST=$(printf "%.0f" "$CPU_GUARANTEE") 

ray start --head --port=6380 --num-cpus=$MY_CPU_REQUEST --dashboard-host=0.0.0.0 --object-manager-port=8076 --node-manager-port=8077 --dashboard-agent-grpc-port=8078 --dashboard-agent-listen-port=52365  --disable-usage-stats --object-store-memory 4294967296

if !  kubectl get svc service-ray-cluster 2>/dev/null > /dev/null; then
    kubectl create -f - <<EOM
# Ray head node service, allowing worker pods to discover the head node to perform the bidirectional communication.
# More contexts can be found at [the Ports configurations doc](https://docs.ray.io/en/latest/ray-core/configure.html#ports-configurations).
apiVersion: v1
kind: Service
metadata:
  name: service-ray-cluster
  labels:
    app: ray-cluster-head
spec:
  clusterIP: None
  ports:
  - name: client
    protocol: TCP
    port: 10001
    targetPort: 10001
  - name: dashboard
    protocol: TCP
    port: 8265
    targetPort: 8265
  - name: gcs-server
    protocol: TCP
    port: 6380
    targetPort: 6380
  selector:
    "dsmlp/app": spark
EOM
fi

# Now fire up workers
/opt/ray-support/start-workers.sh "$@"

# Execution shouldn't reach here unless both start-workers scripts are missing, if so assume that's intentional
exit 0
