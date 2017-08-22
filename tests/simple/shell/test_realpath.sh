#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../../.."

source "${INC_DIR}/subunit.sh"
source "${INC_DIR}/shell_tests.sh"

failed=0

while read -r script; do
	# note: this is intentially mis-spelled realPath
	# so that this does not trigger an error.
	testit "check for use of realPath: $(basename "${script}")" \
		test_real_path "${script}" \
		|| ((failed++))
done <<< "$(find "${BASE_DIR}" -name "*.sh" | grep -v "subunit.sh")"

testok "${0}" "${failed}"
