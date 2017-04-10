#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"
TESTNAME=""

source "${LIB_DIR}/lib.sh"

${TEST_DIR}/test-setup.sh || fail

${TEST_DIR}/test-gk-deploy.sh || fail

${TEST_DIR}/test-dynamic-provisioning.sh || fail

${TEST_DIR}/test-teardown.sh || fail

pass
