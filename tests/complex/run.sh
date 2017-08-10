#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"
TESTNAME=""

source "${LIB_DIR}/lib.sh"

run_test ${TEST_DIR}/test-setup.sh

run_test ${TEST_DIR}/test-gk-deploy.sh

run_test ${TEST_DIR}/test-dynamic-provisioning.sh

run_test ${TEST_DIR}/test-teardown.sh

pass
