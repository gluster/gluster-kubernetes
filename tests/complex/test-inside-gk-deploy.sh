#!/bin/bash

# test gk-deploy

cd ~/deploy


./gk-deploy -y -g -n default ./topology.json

if [[ $? -ne 0 ]]; then
	echo "ERROR: gk-deploy failed"
	exit 1
fi

# wait briefly for pods to settle down...
sleep 2

num_gluster_pods=$(kubectl get pods | grep -s "glusterfs-" | grep -cs "1/1[[:space:]]*Running")
num_heketi_pods=$(kubectl get pods | grep -s "heketi-" | grep -vs "Terminating" | grep -cs "1/1[[:space:]]*Running")

if (( num_heketi_pods != 1 )); then
	echo "ERROR: unexpected number of heketi pods: " \
		"${num_heketi_pods} - " \
		"expected 1"
	exit 1
fi

if (( num_gluster_pods != 3 )); then
	echo "ERROR: unexpected number of gluster pods: " \
		"${num_gluster_pods} - " \
		"expected 3"
	exit 1
fi

echo "PASS"
exit 0
