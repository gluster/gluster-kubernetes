#!/bin/bash

# honor variables set from the caller:
: "${TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"}"
: "${BASE_DIR="${TEST_DIR}/../.."}"
: "${VAGRANT_DIR="${BASE_DIR}/vagrant"}"
: "${DEPLOY_DIR="${BASE_DIR}/deploy"}"
: "${TOPOLOGY_FILE="${DEPLOY_DIR}/topology.json.sample"}"
: "${TESTNAME="$(basename "${0}")"}"
: "${TEST_LOG="${TEST_DIR}/gk-tests.log"}"
: "${SUBTEST_MSG=""}"
: "${SUBTEST_COUNT=0}"
: "${SUBTEST_OUT=1}"
: "${RUN_DEPTH=0}"
: "${RUN_SUMMARY=""}"

SSH_CONFIG=${VAGRANT_DIR}/ssh-config
LOCAL_FAILURE=0

pass() {
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo -en "| \e[32m\e[1mPASS...:\e[21m"
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

		if [[ ${#} -ge 1 ]]; then
			echo -en " ${*}"
		fi

		echo -e "\e[0m"
	fi
}

fail() {
	if [[ "x${TESTNAME}" != "x" ]]; then
		echo -en "| \e[31m\e[1mFAIL...:\e[21m "
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

		if [[ ${#} -ge 1 ]]; then
			echo -en " ${*}"
		fi

		echo -e "\e[0m"
	fi

}

create_vagrant() {
	cd "${VAGRANT_DIR}" || exit 1

	local vstatus
	local run=0

	vstatus=$(vagrant status | grep "master\|node")
	for mstatus in ${vstatus}; do
		if [[ "$(echo "${mstatus}" | grep "running")" == "" ]]; then
			run=1
		fi
	done

	if [[ ${run} -eq 1 ]]; then
		./up.sh || end_test -e "Error bringing up vagrant environment"
	fi

        ssh_config
}

start_vagrant() {
	cd "${VAGRANT_DIR}" || exit 1
	vagrant up --no-provision || end_test -e "Error starting vagrant environment"
}

stop_vagrant() {
	cd "${VAGRANT_DIR}" || exit 1
	vagrant halt || end_test -e "Error halting vagrant environment"
}

destroy_vagrant() {
	cd "${VAGRANT_DIR}" || exit 1
	vagrant destroy || end_test -e "Error destroying vagrant environment"
}

ssh_config() {
	cd "${VAGRANT_DIR}" || exit 1
	vagrant ssh-config > "${SSH_CONFIG}" || end_test -e "Error creating ssh-config"
}

rollback_vagrant() {
	cd "${VAGRANT_DIR}" || exit 1
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

	cd "${VAGRANT_DIR}" || exit 1
	scp -qr -F "${SSH_CONFIG}" "${DEPLOY_DIR}" "${node}:" || end_test -e "SCP deploy to ${node} failed"
	scp -qr -F "${SSH_CONFIG}" "${TOPOLOGY_FILE}" "${node}:deploy/topology.json" || end_test -e "SCP topology to ${node} failed"
}

pull_docker_image() {
	cd "${VAGRANT_DIR}" || exit 1

	local image=${1}
	local vstatus

	vstatus=$(vagrant status | grep "node" | awk '{print $1}')
	for NODE in ${vstatus}; do
		ssh -q -F "${SSH_CONFIG}" "${NODE}" "sudo docker pull ${image}" || end_test -e "Error pulling '${image}' docker image to ${NODE}"
	done
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
		output="$(pass "${@}")"
	else
		output="$(fail "${@}")"
		LOCAL_FAILURE=1
	fi
	if [[ "x${output}" != "x" ]]; then
		echo -e "\r${output}" | tee -a "${TEST_LOG}"
	fi
	SUBTEST_MSG=""
	SUBTEST_OUT=1

	if [[ ${result} -ne 0 ]] && [[ ${e} -eq 1 ]]; then
		exit 1
        fi
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
	else
		echo -e "|====="
	fi
}

end_run() {
	(exit ${LOCAL_FAILURE})
	end_test
	if [[ ${RUN_DEPTH} -eq 0 ]]; then
		echo -e "|=====\n| \e[1mTEST SUMMARY:\e[21m"
		echo -e "$(cat "${TEST_LOG}")"
		rm -f "${TEST_LOG}"
	fi
	exit ${LOCAL_FAILURE}
}

run() {
	local e=""
	local remote=0
	local node
	local script
	local args
	local res

	while [[ "${1}" == -* ]]; do
		if [[ "${1}" == *e* ]]; then
			e="-e"
		fi
		if [[ "${1}" == *r ]]; then
			remote=1
			shift
			node="${1}"
		fi
		shift
	done
	script="${1%% *}"
        args=${1#* }
	shift

	if [[ ${#} -ge 1 ]]; then
		SUBTEST_MSG="${*}"
        fi
	((SUBTEST_COUNT+=1))
	SUBTEST_OUT=0

	((RUN_DEPTH+=1))
	if [[ ${remote} -eq 1 ]]; then
		start_test
		(
		cd "${VAGRANT_DIR}" || exit 1
		scp -q -F "${SSH_CONFIG}" "${script}" "${node}": 1>/dev/null && \
		ssh -qt -F "${SSH_CONFIG}" "${node}" "./$(basename "${script}") ${args}"
		)
		res=${?}
	else
		(
		# shellcheck disable=SC2086
		RUN_DEPTH=${RUN_DEPTH} ${script} ${args}
		)
		res=${?}
	fi
	((RUN_DEPTH-=1))
	(exit ${res})
	end_test ${e}
}

trap end_run EXIT
trap "(exit 1)" ERR
trap "(exit 1)" INT

if [[ ${RUN_DEPTH} -eq 0 ]]; then
	rm -f "${TEST_LOG}"
fi
start_test
