#!/bin/bash

# Modify this script by copying it to your home directory
# *** be sure to remove the "exec" line below from your copy! ***
USERSCRIPT=$HOME/start-workers.sh
if [ -x "$USERSCRIPT" ]; then
    exec "$USERSCRIPT" "$@"
fi

NUM_WORKERS=2

WORKER_CPU_REQUEST=4
WORKER_CPU_LIMIT=8
WORKER_MEM_REQUEST=16384M
WORKER_MEM_LIMIT=16384M
WORKER_GPU_COUNT=0

IMAGE=${JUPYTER_IMAGE_SPEC:-${DOCKER_IMAGE}}
echo "STARTING WORKERS WITH WORKER_CPU_REQUEST=${WORKER_CPU_REQUEST}"
if kubectl get deployment deployment-ray-worker 2>/dev/null > /dev/null; then
	kubectl delete deployment deployment-ray-worker
fi


read -d '' DEPLOYMENT <<EOM
{
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
        "labels": {
            "app": "ray-cluster-worker"
        },
        "name": "deployment-ray-worker"
    },
    "spec": {
        "progressDeadlineSeconds": 600,
        "replicas": ${NUM_WORKERS},
        "selector": {
            "matchLabels": {
                "app": "ray-cluster-worker",
                "component": "ray-worker",
                "type": "ray"
            }
        },
        "template": {
            "metadata": {
                "creationTimestamp": null,
                "labels": {
                    "app": "ray-cluster-worker",
                    "component": "ray-worker",
                    "type": "ray"
                }
            },
            "spec": {
                "containers": [
                    {
                        "args": [
                            "ray start --num-cpus=${WORKER_CPU_REQUEST} --address=service-ray-cluster:6380 --object-manager-port=8076 --node-manager-port=8077 --dashboard-agent-grpc-port=8078 --dashboard-agent-listen-port=52365 --block --object-store-memory=7516192768 --memory=17179869184"
                        ],
                        "command": [
                            "/bin/bash",
                            "-c",
                            "--"
                        ],
                        "env": [
                            {
                                "name": "MY_CPU_REQUEST",
                                "valueFrom": {
                                    "resourceFieldRef": {
                                        "divisor": "0",
                                        "resource": "requests.cpu"
                                    }
                                }
                            }
                        ],
                        "image": "${IMAGE}",
                        "imagePullPolicy": "Always",
                        "name": "ray-worker",
                        "resources": {
                            "limits": {
                                "cpu": "${WORKER_CPU_LIMIT}",
                                "memory": "${WORKER_MEM_LIMIT}"
                            },
                            "requests": {
                                "cpu": "${WORKER_CPU_REQUEST}",
                                "memory": "${WORKER_MEM_REQUEST}"
                            }
                        },
                        "securityContext": {
                            "allowPrivilegeEscalation": false,
                            "runAsUser": ${UID}
                        },
                        "terminationMessagePath": "/dev/termination-log",
                        "terminationMessagePolicy": "File",
                        "volumeMounts": [
                            {
                                "mountPath": "/dev/shm",
                                "name": "dshm"
                            },
                            {
                                "mountPath": "/datasets",
                                "name": "datasets"
                            },
                            {
                                "mountPath": "/home/${USER}/private",
                                "name": "home"
                            },
                             {
                                "mountPath": "/home/${USER}",
                                "name": "course-workspace",
                                "subPath": "home/${USER}"
                             },
                              {
                                "mountPath": "/home/${USER}/public",
                                "name": "course-workspace",
                                "subPath": "public"
                              }
                        ]
                    }
                ],
                "terminationGracePeriodSeconds": 30,
                "volumes": [
                    {
                        "emptyDir": {
                            "medium": "Memory"
                        },
                        "name": "dshm"
                    },
                    {
                        "persistentVolumeClaim": {
                            "claimName": "dsmlp-datasets"
                        },
                        "name": "datasets"
                    },
                    {
                        "persistentVolumeClaim": {
                            "claimName": "home"
                        },
                        "name": "home"
                    }
                ]
            }
        }
    }
}
EOM

VOL=$( kubectl get pod ${HOSTNAME} -o json | jq '.spec.volumes[] | select(.name=="course-workspace")' )

DEPLOYMENT=$( echo "$DEPLOYMENT" | jq --argjson v "$VOL" '.spec.template.spec.volumes += [ $v ]')


# echo "$DEPLOYMENT"
echo "$DEPLOYMENT" | kubectl create -f -
