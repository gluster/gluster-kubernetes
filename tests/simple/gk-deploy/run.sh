#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "${0}")")"

echo "running tests in ${SCRIPT_DIR}"

for test in ${SCRIPT_DIR}/test_*.sh ; do
	$test
	if [ $? -ne 0 ]; then
		exit 1
	fi
done
