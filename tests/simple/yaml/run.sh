#!/bin/bash

SCRIPT_DIR="$(dirname "${0}")"

echo "running tests in ${SCRIPT_DIR}"

failed=0

for test in ${SCRIPT_DIR}/test_*.sh ; do
	${test}
	rc=${?}
	if [[ ${?} -ne 0 ]]; then
		((failed+=rc))
	fi
done

exit ${failed}
