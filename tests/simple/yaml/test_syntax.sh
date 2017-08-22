#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../../.."
DEPLOY_DIR="${BASE_DIR}/deploy"

FAULTY_YAML="${SCRIPT_DIR}/glusterfs-daemonset-wrong.yaml"

source "${INC_DIR}/subunit.sh"

check_yaml () {
	local yaml=${1}
	yamllint -f parsable -d relaxed "${yaml}"
}

check_invalid_yaml () {
	check_yaml "${1}"
	if [[ "x$?" == "x0" ]]; then
		echo "ERROR: parsing invalid yaml succeeded"
		return 1
	fi

	return 0
}

failed=0

if ! which yamllint >/dev/null 2>&1 ; then
	subunit_start_test "yaml syntax tests"
	subunit_skip_test "yaml syntax tests" <<< "yamllint not found"
else
	testit "check invalid yaml" \
		check_invalid_yaml "${FAULTY_YAML}" \
		|| ((failed++))

	while read -r yaml; do
		testit "check $(basename "${yaml}")" \
			check_yaml "${yaml}" \
			|| ((failed++))
	done <<< "$(find "${DEPLOY_DIR}" -name "*.yaml")"
fi

testok "${0}" "${failed}"
