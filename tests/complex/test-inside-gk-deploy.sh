#!/bin/bash

# test gk-deploy

BLOCK=" --no-block"
OBJ=" --no-object"

while [[ "x${1}" != "x" ]]; do
  if [[ "${1}" == "block" ]]; then
    BLOCK=""
  fi
  if [[ "${1}" == obj* ]]; then
    OBJ=" --object-account test-account --object-user test-user --object-password password"
  fi
  shift
done

cd ~/deploy

./gk-deploy -y -g -n default ./topology.json${BLOCK}${OBJ}

if [[ $? -ne 0 ]]; then
	echo "ERROR: gk-deploy failed"
	exit 1
fi

# wait briefly for pods to settle down...
sleep 2

num_gluster_pods=$(kubectl get pods | grep -s "glusterfs-" | grep -s "1/1[[:space:]]*Running" | wc -l)
num_heketi_pods=$(kubectl get pods | grep -s "heketi-" | grep -vs "Terminating" | grep -s "1/1[[:space:]]*Running"  | wc -l)

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

if [[ "${BLOCK}" != " --no-block" ]]; then
	num_block_pods=$(kubectl get pods | grep -s "glusterblock-" | grep -s "1/1[[:space:]]*Running"  | wc -l)

        if (( num_block_pods != 1 )); then
		echo "ERROR: unexpected number of glusterblock pods: " \
			"${num_block_pods} - " \
			"expected 1"
		exit 1
	fi
fi

if [[ "${OBJ}" != " --no-object" ]]; then
	num_object_pods=$(kubectl get pods | grep -s "gluster-s3-" | grep -s "1/1[[:space:]]*Running"  | wc -l)

        if (( num_object_pods != 1 )); then
		echo "ERROR: unexpected number of gluster-s3 pods: " \
			"${num_object_pods} - " \
			"expected 1"
		exit 1
	fi
fi

echo "PASS"
exit 0
