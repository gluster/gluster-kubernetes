#!/bin/bash

sudo yum install -y pv > /dev/null 2>&1

. ./util.sh

desc "show kubernetes nodes"
run "kubectl get nodes,pods"

desc "show storage classes"
run "kubectl get storageclass"

HEKETI_CLI_SERVER=$(kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}')
export HEKETI_CLI_SERVER

#echo HEKETI_CLI_SERVER: $HEKETI_CLI_SERVER

cat > mysc.yaml <<EOF
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: mysc
provisioner: kubernetes.io/glusterfs
parameters:
  endpoint: "heketi-storage-endpoints"
  resturl: "$HEKETI_CLI_SERVER"
  restuser: "obnox"
  restuserkey: "I don't tell you"
EOF

desc "create a storage class (admin)"
run "vim mysc.yaml"
run "kubectl create -f ./mysc.yaml"
run "kubectl get storageclass"


cat > mypvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: mypvc
 annotations:
   volume.beta.kubernetes.io/storage-class: mysc
spec:
 accessModes:
  - ReadWriteMany
 resources:
   requests:
     storage: 2Gi
EOF

desc "create a PVC (user)"
run "vim mypvc.yaml"
run "kubectl create -f ./mypvc.yaml"
run "kubectl get pvc"

PVCstatus=$(kubectl get pvc | grep mypvc | awk '{print $2}')
while [[ "$PVCstatus" == 'pending' ]] ; do
	sleep 1
	PVCstatus=$(kubectl get pvc | grep mypvc | awk '{print $2}')
done

run "kubectl get pvc"
run "kubectl get pv"
run "heketi-cli volume list"

cat > myapp.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    name: myapp
spec:
  containers:
  - name: myapp
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
      claimName: mypvc
EOF

desc "create app using PVC (user)"
run "vim myapp.yaml"
run "kubectl create -f myapp.yaml"
run "kubectl get pods -o wide"

appIP=$(kubectl get pods -o wide | grep myapp | awk '{print $6}')
while [[ "$appIP" == '<none>' ]] ; do
	sleep 1
	appIP=$(kubectl get pods -o wide | grep myapp | awk '{print $6}')
done

run "kubectl get pods -o wide"

run "curl http://$appIP"

run "kubectl exec myapp -- /bin/bash -c \"echo 'Hello, world...' > /usr/share/nginx/html/index.html\""
run "curl http://$appIP"

run "kubectl exec myapp -- /bin/bash -c \"cat /proc/mounts | grep nginx\""

mountinfo=$(kubectl exec myapp -- /bin/bash -c "cat /proc/mounts | grep nginx" | awk '{print $1}')
volname=$(echo -n "${mountinfo}" | cut -d: -f2)
glusterip=$(echo -n "${mountinfo}" |cut -d: -f1)
glusterpod=$(kubectl get pods -o wide | grep "${glusterip}" | awk '{print $1}')

brickinfopath="/var/lib/glusterd/vols/${volname}/bricks"
brickinfofile=$(kubectl exec "${glusterpod}" -- /bin/bash -c "ls -1 ${brickinfopath} | head -n 1")
brickpath=$(kubectl exec "${glusterpod}" -- /bin/bash -c "cat ${brickinfopath}/${brickinfofile} | grep real_path | cut -d= -f2")
brickhost=$(kubectl exec "${glusterpod}" -- /bin/bash -c "cat ${brickinfopath}/${brickinfofile} | grep hostname | cut -d= -f2")
brickpod=$(kubectl get pods -o wide | grep "${brickhost}" | awk '{print $1}')

run "kubectl exec ${brickpod} -- /bin/bash -c \"cat ${brickpath}/index.html\""

desc "demo-dynamic-provisioning: done"
