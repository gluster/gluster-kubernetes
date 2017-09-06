#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
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
	local args=( -y )

	OUT=$("${GK_DEPLOY}" "${args[@]}")
	local rc=${?}

	echo "cmd: '${GK_DEPLOY} ${args[*]}'"
	echo "output:"
	echo "${OUT}"

	if [[ ${rc} == 0 ]]; then
		echo "ERROR: script without topology succeeded"
		return 1
	fi

	return 0
}

test_cli_not_found () {
	local args=( -y )
	local expected_out="Container platform CLI (e.g. kubectl, oc) not found."

	OUT=$(PATH='/doesnotexist' "${GK_DEPLOY}" "${args[@]}" "${TOPOLOGY}")
	local rc=${?}

	echo "cmd: 'PATH='/doesnotexist' ${GK_DEPLOY} ${args[*]} ${TOPOLOGY}'"
	echo "output:"
	echo "${OUT}"

	if [[ ${rc} == 0 ]]; then
		echo "ERROR: script succeeded"
		return 1
	fi

	if [[ ${rc} != 1 ]]; then
		echo "ERROR: script returned ${rc}, expected 1"
		return 1
	fi

	if [[ "${OUT}" != "${expected_out}" ]]; then
		echo "ERROR: expected \"${expected_out}\" in output"
		return 1
	fi

	return 0

}

test_cli_unknown () {
	local cli="${1}"
	local args=( -y -c "${cli}" )
	local expected_out="Unknown CLI '${cli}'."

	OUT=$("${GK_DEPLOY}" "${args[@]}" "${TOPOLOGY}")
	local rc=${?}

	echo "cmd: '${GK_DEPLOY} ${args[*]} ${TOPOLOGY}'"
	echo "output:"
	echo "${OUT}"

	if [[ ${rc} == 0 ]]; then
		echo "ERROR: script succeeded"
		return 1
	fi

	if [[ ${rc} != 1 ]]; then
		echo "ERROR: script returned ${rc}, expected 1"
		return 1
	fi

	if [[ "${OUT}" != "${expected_out}" ]]; then
		echo "ERROR: expected \"${expected_out}\" in output"
		return 1
	fi

	return 0
}

test_namespace_invalid () {
	local cli="${1}"
	local args=( -y -c "${1}" -n invalid )
	local expected_out="Namespace 'invalid' not found"

	# shellcheck disable=SC2086
	OUT=$("${GK_DEPLOY}" "${args[@]}" "${TOPOLOGY}")
	local rc=${?}

	echo "cmd: '${GK_DEPLOY} ${args[*]} ${TOPOLOGY}'"
	echo "output:"
	echo "${OUT}"

	if [[ ${rc} == 0 ]]; then
		echo "ERROR: script succeeded"
		return 1
	fi

	if [[ ${rc} != 1 ]]; then
		echo "ERROR: script returned ${rc}, expected 1"
		return 1
	fi

	if [[ "${OUT}" != *"${expected_out}"* ]]; then
		echo "ERROR: expected \"${expected_out}\" in output"
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

testit "test namespace invalid oc" \
	test_namespace_invalid oc \
	|| ((failed++))

testit "test namespace invalid kubectl" \
	test_namespace_invalid kubectl \
	|| ((failed++))

testok "${0}" "${failed}"
