#!/bin/bash

# honor variables set from the caller:
: ${TEST_DIR:="$(realpath $(dirname $0))"}
: ${BASE_DIR:="${TEST_DIR}/../.."}
: ${VAGRANT_DIR:="${BASE_DIR}/vagrant"}
: ${DEPLOY_DIR:="${BASE_DIR}/deploy"}
: ${TESTNAME:="$(basename $0)"}

SSH_CONFIG=${VAGRANT_DIR}/ssh-config

pass() {
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo "PASS: ${TESTNAME}"
	else
		echo "PASS"
	fi

	exit 0
}

fail() {
	# print an additional message if given
	if [[ $# -ge 1 ]]; then
		echo "$*"
	fi

	if [[ "x${TESTNAME}" != "x" ]]; then
		echo "FAIL: ${TESTNAME}"
	else
		echo "FAIL"
	fi

	exit 1
}

create_vagrant() {
	cd ${VAGRANT_DIR}
	./up.sh
}

start_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant up --no-provision
}

stop_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant halt
}

destroy_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant destroy
}

ssh_config() {
	cd ${VAGRANT_DIR}
	vagrant ssh-config > ${SSH_CONFIG}
}

copy_deploy() {
	cd ${VAGRANT_DIR}
	scp -r -F ${SSH_CONFIG} ${DEPLOY_DIR} master:
	ssh -F ${SSH_CONFIG} master "cp deploy/topology.json.sample deploy/topology.json"
}

pull_docker_image() {
	cd ${VAGRANT_DIR}
	for NODE in node0 node1 node2 ; do
		ssh -F ${SSH_CONFIG} $NODE "sudo docker pull gcr.io/google_containers/nginx-slim:0.8"
	done
}

run_on_node() {
	script=$(realpath $1)
	shift
	node=$1
	shift

	cd ${VAGRANT_DIR}

	scp -F "${SSH_CONFIG}" "${script}" "${node}":
	ssh -t -F "${SSH_CONFIG}" "${node}" "./$(basename ${script})"
}
