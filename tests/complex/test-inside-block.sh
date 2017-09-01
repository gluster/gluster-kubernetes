#!/bin/bash

# test dynamic provisioning

HEKETI_CLI_SERVER=$(kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}')
export HEKETI_CLI_SERVER

# SC

SC="mysc"

cat > "${SC}.yaml" <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${SC}
  labels:
    glusterfs: block-sc
    glusterblock: sc
provisioner: gluster.org/glusterblock
parameters:
  resturl: "${HEKETI_CLI_SERVER}"
  restauthenabled: "false"
  opmode: "heketi"
  hacount: "1"
  chapauthenabled: "false"
EOF

echo "creating a storage class"
kubectl create -f "./${SC}.yaml"

#TODO: check existence of sc
kubectl get storageclass


# PVC

PVC="mypvc"

cat > "${PVC}.yaml" <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ${PVC}
  annotations:
    volume.beta.kubernetes.io/storage-class: "${SC}"
  labels:
    glusterfs: block-pvc
    glusterblock: pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

echo "creating a PVC"
kubectl create -f "./${PVC}.yaml"


echo "verifying the pvc has been created and bound"
s=0
PVCstatus=$(kubectl get pvc | grep "${PVC}" | awk '{print $2}')
while [[ "$PVCstatus" != 'Bound' ]]; do
	if [[ ${s} -ge 30 ]]; then
		echo "Timeout waiting for PVC"
		exit 1
        fi
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
    glusterblock: nginx-app
spec:
  containers:
  - image: "gcr.io/google_containers/nginx-slim:0.8"
    name: nginx-block
    ports:
    - containerPort: 80
      name: web
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: glusterblock-vol
  volumes:
  - name: glusterblock-vol
    persistentVolumeClaim:
      claimName: ${PVC}
EOF

echo "creating an app for using the PVC"
kubectl create -f "${APP}.yaml"

# wait for the app to be created and have an IP

echo "waiting for app pod to become available"
s=0
appIP=$(kubectl get pods -o wide | grep "${APP}" | awk '{print $6}')
while [[ "$appIP" == '<none>' ]] ; do
	if [[ ${s} -ge 60 ]]; then
		echo "Timeout waiting for pod"
		exit 1
        fi
	sleep 1
        ((s+=1))
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

pv=$(kubectl get pvc -o wide | grep "${PVC}" | awk '{print $3}')
pv_annotations=$(kubectl get pv ${pv} -o go-template="{{ .metadata.annotations }}")
blockvol=$(for key in ${pv_annotations}; do echo $key | grep glusterBlockShare | cut -d: -f2 | cut -d_ -f2 | cut -d] -f1; done)
heketi_pod=$(kubectl get po --selector=heketi=pod | grep "heketi" | awk '{print $1}')
blockinfo=$(kubectl exec  "${heketi_pod}" -- heketi-cli -s http://localhost:8080 blockvolume info "${blockvol}")
blockfile=$(echo "${blockinfo}" | grep IQN | cut -d: -f3)
hostvol=$(echo "${blockinfo}" | grep Hosting | awk '{print $4}')
hostnode=$(echo "${blockinfo}" | grep Hosts | cut -d\[ -f2 | cut -d] -f1)
tempdir1=$(mktemp -d)
tempdir2=$(mktemp -d)

cleanup_mounts() {
	sudo umount "${tempdir2}" || echo "Failed to unmount ${tempdir2}"
	sudo umount "${tempdir1}" || echo "Failed to unmount ${tempdir1}"
	rm -rf "${tempdir2}"
	rm -rf "${tempdir1}"
}

sudo mount -t glusterfs "${hostnode}:/vol_${hostvol}" "${tempdir1}" || { echo "Failed to mount block hosting volume"; cleanup_mounts; exit 1; }
sudo mount -o loop "${tempdir1}/block-store/${blockfile}" "${tempdir2}" || { echo "Failed to mount block volume file"; cleanup_mounts; exit 1; }

BRICK_CONTENT=$(cat "${tempdir2}/index.html")
cleanup_mounts
if [[ "${BRICK_CONTENT}" != "${CONTENT}" ]]; then
	echo "ERROR: did not get expected content from block file"
	exit 1
fi

echo "cleaning up"
kubectl delete pod "${APP}"
s=0
appIP=$(kubectl get pods -o wide | grep "${APP}" | awk '{print $6}')
while [[ "$appIP" != '' ]] ; do
	if [[ ${s} -ge 30 ]]; then
		echo "Timeout waiting for pod to terminate"
		exit 1
        fi
	sleep 1
        ((s+=1))
	appIP=$(kubectl get pods -o wide | grep "${APP}" | awk '{print $6}')
done

kubectl delete pvc "${PVC}"
s=0
PVCstatus=$(kubectl get pvc | grep "${PVC}" | awk '{print $2}')
while [[ "$PVCstatus" != '' ]]; do
	if [[ ${s} -ge 30 ]]; then
		echo "Timeout waiting for PVC to terminate"
		exit 1
        fi
	sleep 1
        ((s+=1))
	PVCstatus=$(kubectl get pvc | grep "${PVC}" | awk '{print $2}')
done

kubectl delete storageclass "${SC}"

exit 0
