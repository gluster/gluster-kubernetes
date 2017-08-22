#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../../.."

source "${INC_DIR}/subunit.sh"
source "${INC_DIR}/shell_tests.sh"

failed=0

find_scripts() {
	find "${BASE_DIR}" -name "*.sh" | grep -v "subunit.sh"
	find "${TESTS_DIR}/gk-deploy/stubs" -type f | grep -v "txt$" | grep -v "~$"
}

while read -r script; do
	# note: this is intentially mis-spelled realPath
	# so that this does not trigger an error.
	testit "check for use of realPath: $(basename "${script}")" \
		test_real_path "${script}" \
		|| ((failed++))
done <<< "$(find_scripts)"

testok "${0}" "${failed}"
