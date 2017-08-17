#!/bin/bash

# test dynamic provisioning

HEKETI_CLI_SERVER=$(kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}')
export HEKETI_CLI_SERVER


# SC

SC="mysc"

cat > "${SC}.yaml" <<EOF
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: ${SC}
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "${HEKETI_CLI_SERVER}"
EOF

echo "creating a storage class"
kubectl create -f "./${SC}.yaml"

#TODO: check existence of sc
kubectl get storageclass


# PVC

PVC="mypvc"

cat > "${PVC}.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: ${PVC}
 annotations:
   volume.beta.kubernetes.io/storage-class: ${SC}
spec:
 accessModes:
  - ReadWriteMany
 resources:
   requests:
     storage: 2Gi
EOF

echo "creating a PVC"
kubectl create -f "./${PVC}.yaml"


echo "verifying the pvc has been created and bound"
s=0
PVCstatus=$(kubectl get pvc | grep "${PVC}" | awk '{print $2}')
while [[ "$PVCstatus" != 'Bound' ]] && [[ ${s} -lt 30 ]]; do
	sleep 1
        ((s+=1))
	PVCstatus=$(kubectl get pvc | grep "${PVC}" | awk '{print $2}')
done


# APP

APP="myapp"

cat > "${APP}.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${APP}
  labels:
    name: ${APP}
spec:
  containers:
  - name: ${APP}
    image: gcr.io/google_containers/nginx-slim:0.8
    ports:
    - name: web
      containerPort: 80
    volumeMounts:
    - name: mypv
      mountPath: /usr/share/nginx/html
  volumes:
  - name: mypv
    persistentVolumeClaim:
      claimName: ${PVC}
EOF

echo "creating an app for using the PVC"
kubectl create -f "${APP}.yaml"

# wait for the app to be created and have an IP

echo "waiting for app pod to become available"
appIP=$(kubectl get pods -o wide | grep "${APP}" | awk '{print $6}')
while [[ "$appIP" == '<none>' ]] ; do
	sleep 1
	appIP=$(kubectl get pods -o wide | grep "${APP}" | awk '{print $6}')
done


echo "putting content into application"
CONTENT="Does this work? Yes! Great!!!"
kubectl exec "${APP}" -- /bin/bash -c "echo \"${CONTENT}\" > /usr/share/nginx/html/index.html"


echo "verifying we get back our content from the app"
OUTPUT="$(curl "http://${appIP}")"

if [[ "${OUTPUT}" != "${CONTENT}" ]]; then
	echo "ERROR: did not get expected output from nginx pod"
	exit 1
fi


echo "verifying the content is actually stored on gluster"
mountinfo=$(kubectl exec "${APP}" -- /bin/bash -c "cat /proc/mounts | grep nginx" | awk '{print $1}')
volname=$(echo -n "${mountinfo}" | cut -d: -f2)
glusterip=$(echo -n "${mountinfo}" |cut -d: -f1)
glusterpod=$(kubectl get pods -o wide | grep "${glusterip}" | awk '{print $1}')

brickinfopath="/var/lib/glusterd/vols/${volname}/bricks"
brickinfofile=$(kubectl exec "${glusterpod}" -- /bin/bash -c "ls -1 ${brickinfopath} | head -n 1")
brickpath=$(kubectl exec "${glusterpod}" -- /bin/bash -c "cat ${brickinfopath}/${brickinfofile} | grep real_path | cut -d= -f2")
brickhost=$(kubectl exec "${glusterpod}" -- /bin/bash -c "cat ${brickinfopath}/${brickinfofile} | grep hostname | cut -d= -f2")
brickpod=$(kubectl get pods -o wide | grep "${brickhost}" | awk '{print $1}')

BRICK_CONTENT=$(kubectl exec "${brickpod}" -- /bin/bash -c "cat ${brickpath}/index.html")
if [[ "${BRICK_CONTENT}" != "${CONTENT}" ]]; then
	echo "ERROR: did not get expected content from brick"
	exit 1
fi

echo "cleaning up"
kubectl delete pod "${APP}"
kubectl delete pvc "${PVC}"
kubectl delete storageclass "${SC}"

exit 0
