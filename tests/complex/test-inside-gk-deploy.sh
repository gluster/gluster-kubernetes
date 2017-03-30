#!/bin/bash

# test gk-deploy

cd ~/deploy

num_gluster_pods_before=$(kubectl get pods | grep -s "glusterfs-" | wc -l)
num_heketi_pods_before=$(kubectl get pods | grep -s "heketi-" | wc -l)

./gk-deploy -y -g -n default ./topology.json

if [[ $? -ne 0 ]]; then
	echo "ERROR: gk-deploy failed"
	exit 1
fi

# wait briefly for pods to settle down...
sleep 2

num_gluster_pods_after=$(kubectl get pods | grep -s "glusterfs-" | wc -l)
num_heketi_pods_after=$(kubectl get pods | grep -s "heketi-" | grep -vs "deploy-heketi" | wc -l)

if (( num_heketi_pods_after - num_heketi_pods_before != 1 )); then
	echo "ERROR: unexpected number of heketi pods: " \
		"${num_heketi_pods_after} - " \
		"expected $(( num_heketi_pods_before + 1 ))"
	exit 1
fi

if (( num_gluster_pods_after - num_gluster_pods_before != 3 )); then
	echo "ERROR: unexpected number of gluster pods: " \
		"${num_gluster_pods_after} - " \
		"expected $(( num_gluster_pods_before + 3 ))"
	exit 1
fi

echo "PASS"
exit 0
