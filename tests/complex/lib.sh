#!/bin/bash

# honor variables set from the caller:
: ${TEST_DIR:="$(realpath $(dirname $0))"}
: ${BASE_DIR:="${TEST_DIR}/../.."}
: ${VAGRANT_DIR:="${BASE_DIR}/vagrant"}
: ${DEPLOY_DIR:="${BASE_DIR}/deploy"}
: ${TOPOLOGY_FILE:="${DEPLOY_DIR}/topology.json.sample"}
: ${TESTNAME:="$(basename $0)"}
: ${SUBTEST_MSG:=""}
: ${SUBTEST_COUNT:=0}
: ${SUBTEST_OUT:=1}

SSH_CONFIG=${VAGRANT_DIR}/ssh-config

pass() {
	echo -en "| \e[32m\e[1mPASS...:\e[21m"
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo -en " ${TESTNAME}"
		# print subtest information if we haven't yet
		if [[ ${SUBTEST_OUT} -eq 0 ]]; then
			if [[ ${SUBTEST_COUNT} -gt 0 ]]; then
				echo -en ":${SUBTEST_COUNT}"
			fi
			if [[ "x${SUBTEST_MSG}" != "x" ]]; then
				echo -en ": ${SUBTEST_MSG}"
				SUBTEST_MSG=""
			fi
			SUBTEST_OUT=1
		fi
	fi

	if [[ ${#} -ge 1 ]]; then
		echo -en " ${*}"
	elif [[ "x${TESTNAME}" == "x" ]]; then
		echo -en " DONE"
        fi

	echo -e "\e[0m"
}

fail() {
	echo -en "| \e[31m\e[1mFAIL...:\e[21m "
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo -en "${TESTNAME}"
		# print subtest information if we haven't yet
		if [[ ${SUBTEST_OUT} -eq 0 ]]; then
			if [[ ${SUBTEST_COUNT} -gt 0 ]]; then
				echo -en ":${SUBTEST_COUNT}"
			fi
			if [[ "x${SUBTEST_MSG}" != "x" ]]; then
				echo -en ": ${SUBTEST_MSG}"
				SUBTEST_MSG=""
			fi
			SUBTEST_OUT=1
		fi
	fi

	if [[ ${#} -ge 1 ]]; then
		echo -en " ${*}"
	elif [[ "x${TESTNAME}" == "x" ]]; then
		echo -en " EXIT"
        fi

	echo -e "\e[0m"

	exit 1
}

create_vagrant() {
	cd ${VAGRANT_DIR}
	./up.sh || fail "Error bringing up vagrant environment"
}

start_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant up --no-provision || fail "Error starting vagrant environment"
}

stop_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant halt || fail "Error halting vagrant environment"
}

destroy_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant destroy || fail "Error destroying vagrant environment"
}

ssh_config() {
	cd ${VAGRANT_DIR}
	vagrant ssh-config > ${SSH_CONFIG} || fail "Error creating ssh-config"
}

rollback_vagrant() {
	cd ${VAGRANT_DIR}
	(
	if vagrant plugins | grep -q sahara; then
		vagrant sandbox rollback
		for m in $(vagrant status | grep running | awk '{print $1}'); do
			vagrant ssh $m -c "sudo systemctl restart docker kubelet"
		done
	else
		destroy_vagrant
		create_vagrant
		ssh_config
	fi
        ) || fail "Error rolling back vagrant environment"
}

copy_deploy() {
	local node=${1:-master}

	cd ${VAGRANT_DIR}
	ssh -q -F "${SSH_CONFIG}" master "mkdir -p ~/deploy" || fail "SSH connection to ${node} failed"
	scp -qr -F "${SSH_CONFIG}" "${DEPLOY_DIR}/"* "${TOPOLOGY_FILE}" ${node}:~/deploy/ || fail "SCP deploy to ${node} failed"
}

pull_docker_image() {
	local image=$1
	cd ${VAGRANT_DIR}
	for NODE in node0 node1 node2 ; do
		ssh -q -F ${SSH_CONFIG} ${NODE} "sudo docker pull ${image}"
	done
}

start_test() {
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo -en "| \e[32m\e[1mRUNNING:\e[21m ${TESTNAME}"
		# print a subtest number if counting
		if [[ ${SUBTEST_COUNT} -gt 0 ]]; then
			echo -en ":${SUBTEST_COUNT}"
		fi
		# print a subtest message if given
		if [[ "x${SUBTEST_MSG}" != "x" ]]; then
			echo -en ": ${SUBTEST_MSG}"
		fi
		echo -e "\e[0m"
	fi
}

end_test() {
	if [[ ${?} -eq 0 ]]; then
		pass
	else
		fail
	fi
}

run_on_node() {
	script=$(realpath $1)
	shift
	node=$1
	shift

	if [[ ${#} -ge 1 ]]; then
		SUBTEST_MSG="${*}"
        fi
	(( SUBTEST_COUNT += 1 ))
	SUBTEST_OUT=0

	start_test

	cd ${VAGRANT_DIR}

	scp -q -F "${SSH_CONFIG}" "${script}" "${node}": || fail "SCP ${script} to ${node} failed"
	ssh -qt -F "${SSH_CONFIG}" "${node}" "./$(basename ${script})" || fail "SSH connection to ${node} failed"

	end_test
}

trap end_test EXIT
start_test
