#!/bin/bash

SCRIPT_DIR=$(cd $(dirname ${0}); pwd)
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../../.."
DEPLOY_DIR="${BASE_DIR}/deploy"

FAULTY_YAML="${SCRIPT_DIR}/glusterfs-daemonset-wrong.yaml"

source "${INC_DIR}/subunit.sh"
source "${INC_DIR}/shell_tests.sh"

failed=0

for script in $(find ${BASE_DIR} -name "*.sh" | grep -v "subunit.sh") ; do
	testit "check basic syntax: $(basename ${script})" \
		test_shell_syntax ${script} \
		|| ((failed++))
	testit "shellcheck: $(basename ${script})" \
		test_shellcheck ${script} \
		|| ((failed++))
done

testok $0 ${failed}
