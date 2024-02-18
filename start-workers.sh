#!/bin/bash

# Modify this script by copying it to your home directory
# *** be sure to remove the "exec" line below from your copy! ***
USERSCRIPT=$HOME/start-workers.sh
if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi

NUM_WORKERS=1

WORKER_CPU_REQUEST=8
WORKER_CPU_LIMIT=8
WORKER_MEM_REQUEST=16384M
WORKER_MEM_LIMIT=16384M
WORKER_GPU_COUNT=0

# Jupyter pod's stop hook _should_ delete the deployment, but check again just in case
if kubectl get deployment deployment-ray-worker 2>/dev/null > /dev/null; then
	kubectl delete -f deployment deployment-ray-worker
fi

kubectl create -f - <<EOM
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-ray-worker
  labels:
    app: ray-cluster-worker
spec:
  # Change this to scale the number of worker nodes started in the Ray cluster.
  replicas: ${NUM_WORKERS}
  selector:
    matchLabels:
      component: ray-worker
      type: ray
      app: ray-cluster-worker
  template:
    metadata:
      labels:
        component: ray-worker
        type: ray
        app: ray-cluster-worker
    spec:
      restartPolicy: Always
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
      securityContext:
        runAsUser: $(id -u)
      containers:
      - name: ray-worker
        image: "${JUPYTER_IMAGE_SPEC}"
        imagePullPolicy: Always
        command: ["/bin/bash", "-c", "--"]
        args:
          - "ray start --num-cpus=${WORKER_CPU_REQUEST} --address=service-ray-cluster:6380 --object-manager-port=8076 --node-manager-port=8077 --dashboard-agent-grpc-port=8078 --dashboard-agent-listen-port=52365 --block"
        securityContext:
          allowPrivilegeEscalation: false
        # This volume allocates shared memory for Ray to use for its plasma
        # object store. If you do not provide this, Ray will fall back to
        # /tmp which cause slowdowns if it's not a shared memory volume.
        volumeMounts:
          - mountPath: /dev/shm
            name: dshm
        env:
          # This is used in the ray start command so that Ray can spawn the
          # correct number of processes. Omitting this may lead to degraded
          # performance.
          - name: MY_CPU_REQUEST
            valueFrom:
              resourceFieldRef:
                resource: requests.cpu
          # The resource requests and limits in this config are too small for production!
          # It is better to use a few large Ray pods than many small ones.
          # For production, it is ideal to size each Ray pod to take up the
          # entire Kubernetes node on which it is scheduled.
        resources:
          limits:
            cpu: "${WORKER_CPU_LIMIT}"
            memory: "${WORKER_MEM_LIMIT}"
            # For production use-cases, we recommend specifying integer CPU reqests and limits.
            # We also recommend setting requests equal to limits for both CPU and memory.
            # For this example, we use a 500m CPU request to accomodate resource-constrained local
            # Kubernetes testing environments such as Kind and minikube.
          requests:
            cpu: "${WORKER_CPU_REQUEST}"
            memory: "${WORKER_MEM_REQUEST}"
EOM
