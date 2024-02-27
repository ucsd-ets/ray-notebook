#!/bin/bash

NUM_WORKERS=2

WORKER_CPU_REQUEST=3
WORKER_CPU_LIMIT=3
WORKER_MEM_REQUEST=8192M
WORKER_MEM_LIMIT=8192M
WORKER_GPU_COUNT=0

IMAGE=${JUPYTER_IMAGE_SPEC:-${DOCKER_IMAGE}}

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
                            "ray start --num-cpus=${WORKER_CPU_REQUEST} --address=service-ray-cluster:6380 --object-manager-port=8076 --node-manager-port=8077 --dashboard-agent-grpc-port=8078 --dashboard-agent-listen-port=52365 --block --object-store-memory 4294967296 --memory 7516192768"
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
                        "image": ${IMAGE},
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
                            "allowPrivilegeEscalation": false
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
                    }
                ]
            }
        }
    }
}
EOM

VOL=$( kubectl get pod ${HOSTNAME} -o json | jq '.spec.volumes[] | select(.name=="course-workspace")' )

read -d '' VOLMNT <<"EOM"
{
	"mountPath": "/public",
	"name": "course-workspace",
	"subPath": "public"
}
EOM

DEPLOYMENT=$( echo "$DEPLOYMENT" | jq --argjson v "$VOL" '.spec.template.spec.volumes += [ $v ]')
DEPLOYMENT=$( echo "$DEPLOYMENT" | jq --argjson v "$VOLMNT" '.spec.template.spec.containers[0].volumeMounts += [ $v ]')

echo "$DEPLOYMENT" | kubectl create -f -
