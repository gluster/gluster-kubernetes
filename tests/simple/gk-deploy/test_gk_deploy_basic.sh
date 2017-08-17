#!/bin/bash

SCRIPT_DIR=$(cd $(dirname ${0}); pwd)
STUBS_DIR="${SCRIPT_DIR}/stubs"
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../../.."
DEPLOY_DIR="${BASE_DIR}/deploy"

GK_DEPLOY="${DEPLOY_DIR}/gk-deploy"
TOPOLOGY="${DEPLOY_DIR}/topology.json.sample"

PATH="${STUBS_DIR}:$PATH"

source "${INC_DIR}/subunit.sh"
source "${INC_DIR}/shell_tests.sh"

test_missing_topology () {
	${GK_DEPLOY} -y
	if [[ "x$?" == "x0" ]]; then
		echo "ERROR: gk_deploy without toplogoy succeeded"
		return 1
	fi

	return 0
}

test_cli_not_found () {
	local expected_out="Container platform CLI (e.g. kubectl, oc) not found."

	OUT=$(PATH="/doesnotexist" "${GK_DEPLOY}" -y "${TOPOLOGY}")
	local rc=${?}

	if [[ "x${rc}" == "x0" ]]; then
		echo "ERROR: gk-deploy succeeded "\
			"(output: \"${OUT}\")"
		return 1
	fi

	if [[ "x${rc}" != "x1" ]]; then
		echo "ERROR: gk-deploy gave ${rc}, " \
			"expected 1 (output: \"${OUT}\")"
		return 1
	fi

	if [[ "${OUT}" != "${expected_out}" ]]; then
		echo "ERROR: got output '${OUT}', expected '${expected_out}'"
		return 1
	fi

	return 0

}

test_cli_unknown () {
	local cli="${1}"
	local expected_out="Unknown CLI '${cli}'."

	OUT=$(${GK_DEPLOY} -y -c ${cli} ${TOPOLOGY})
	local rc=$?

	if [[ "x${rc}" == "x0" ]]; then
		echo "ERROR: gk-deploy -c ${cli} succeeded "\
			"(output: \"${OUT}\")"
		return 1
	fi

	if [[ "x${rc}" != "x1" ]]; then
		echo "ERROR: gk-deploy -c ${cli} gave ${rc}, " \
			"expected 1 (output: \"${OUT}\")"
		return 1
	fi

	if [[ "${OUT}" != "${expected_out}" ]]; then
		echo "ERROR: got output '${OUT}', expected '${expected_out}'"
		return 1
	fi

	return 0
}

test_namespace_invalid () {
	local cli=""
	local args="-y -n invalid"
	local expected_out="Using OpenShift CLI.
Namespace 'invalid' not found."

	if [[ "x${#}" != "x0" ]]; then
		cli="${1}"
		if [[ "x${cli}" == "xkubectl" ]]; then
			expected_out="Using Kubernetes CLI.
Namespace 'invalid' not found."
		elif [[ "x${cli}" != "xoc" ]]; then
			expected_out="Unknown CLI '${cli}'."
		fi
		args="${args} -c ${cli}"
	fi

	OUT=$(${GK_DEPLOY} ${args} ${TOPOLOGY})
	local rc=$?

	echo "cmd: '${GK_DEPLOY} ${args} ${TOPOLOGY}'"
	echo "out: '${OUT}'"

	if [[ "x${rc}" == "x0" ]]; then
		echo "ERROR: gk-deploy ${args} succeeded "\
			"(output: \"${OUT}\")"
		return 1
	fi

	if [[ "x${rc}" != "x1" ]]; then
		echo "ERROR: gk-deploy ${args} gave ${rc}, " \
			"expected 1 (output: \"${OUT}\")"
		return 1
	fi

	if [[ "${OUT}" != "${expected_out}" ]]; then
		echo "ERROR: got output '${OUT}', expected '${expected_out}'"
		return 1
	fi

	return 0
}

failed=0

testit "test script syntax" \
	test_shell_syntax "${GK_DEPLOY}" \
	|| ((failed++))

testit "test shellcheck" \
	test_shellcheck "${GK_DEPLOY}" \
	|| ((failed++))

testit "test missing topology" \
	test_missing_topology \
	|| ((failed++))

testit "test cli not found" \
	test_cli_not_found \
	|| ((failed++))

testit "test cli does not exist" \
	test_cli_unknown doesnotexist \
	|| ((failed++))

testit "test cli unknown" \
	test_cli_unknown /usr/bin/true \
	|| ((failed++))

testit "test namespace invalid" \
	test_namespace_invalid \
	|| ((failed++))

testit "test namespace invalid kubectl" \
	test_namespace_invalid kubectl \
	|| ((failed++))

testit "test namespace invalid unknown-cli" \
	test_namespace_invalid unknown-cli \
	|| ((failed++))

testok $0 ${failed}
