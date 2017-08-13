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
: ${RUN_SUMMARY:=""}

SSH_CONFIG=${VAGRANT_DIR}/ssh-config
LOCAL_FAILURE=0

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
			fi
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
			fi
		fi
	fi

	if [[ ${#} -ge 1 ]]; then
		echo -en " ${*}"
	elif [[ "x${TESTNAME}" == "x" ]]; then
		echo -en " EXIT"
        fi

	echo -e "\e[0m"
}

create_vagrant() {
	cd ${VAGRANT_DIR}

	local vstatus=$(vagrant status | awk '{print $1}')
	local run=0
	for m in ${vstatus}; do
		mstatus=$(vagrant status ${m} 2>&1)
		mres=${?}
		if [[ ${mres} -eq 0 ]] && [[ "$(echo "${mstatus}" | grep "running")" == "" ]]; then
			run=1
		fi
	done

	if [[ ${run} -eq 1 ]]; then
		./up.sh || end_test -e "Error bringing up vagrant environment"
	fi

        ssh_config
}

start_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant up --no-provision || end_test -e "Error starting vagrant environment"
}

stop_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant halt || end_test -e "Error halting vagrant environment"
}

destroy_vagrant() {
	cd ${VAGRANT_DIR}
	vagrant destroy || end_test -e "Error destroying vagrant environment"
}

ssh_config() {
	cd ${VAGRANT_DIR}
	vagrant ssh-config > ${SSH_CONFIG} || end_test -e "Error creating ssh-config"
}

rollback_vagrant() {
	cd ${VAGRANT_DIR}
	(
        ./rollback.sh
	if [[ ${?} -ne 0 ]]; then
		destroy_vagrant
		create_vagrant
		ssh_config
	fi
        ) || end_test -e "Error rolling back vagrant environment"
}

copy_deploy() {
	local node=${1:-master}

	cd ${VAGRANT_DIR}
	scp -qr -F "${SSH_CONFIG}" "${DEPLOY_DIR}" "${TOPOLOGY_FILE}" ${node}: || end_test -e "SCP deploy to ${node} failed"
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
	local result="${?}"
	local output=""
	local e=0
	if [[ "${1}" == "-e" ]]; then
		e=1
		shift
	fi
	if [[ ${result} -eq 0 ]]; then
		output=$(pass ${@})
	else
		output=$(fail ${@})
		LOCAL_FAILURE=1
	fi
	echo -e "\n${output}"
	RUN_SUMMARY+="${output}\n"
	SUBTEST_MSG=""
	SUBTEST_OUT=1

	if [[ ${result} -ne 0 ]] && [[ ${e} -eq 1 ]]; then
		exit 1
        fi
}

end_run() {
	(exit ${LOCAL_FAILURE})
	end_test
	echo -e "|=====\n| \e[1mTEST SUMMARY:\e[21m"
	echo -e "${RUN_SUMMARY}"
}

run_on_node() {
	local e=""
	if [[ "${1}" == "-e" ]]; then
		e="-e"
		shift
	fi
	local script=$(realpath ${1%% *})
        local args=${1#[^ ]+}
        echo "SCRIPT: $script"
        echo "ARGS: $args"
	shift
	local node=$1
	shift

	if [[ ${#} -ge 1 ]]; then
		SUBTEST_MSG="${*}"
        fi
	(( SUBTEST_COUNT += 1 ))
	SUBTEST_OUT=0

	start_test

	cd ${VAGRANT_DIR}

	(
	scp -q -F "${SSH_CONFIG}" "${script}" "${node}": 1>/dev/null && ssh -qt -F "${SSH_CONFIG}" "${node}" "./$(basename ${script}) ${args}"
	)

	end_test ${e}
}

trap end_run EXIT
trap end_test ERR
start_test
