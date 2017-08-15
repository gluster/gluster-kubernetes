#!/bin/bash

TEST_DIR="$(realpath "$(dirname "${0}")")"
LIB_DIR="${TEST_DIR}"
# shellcheck disable=SC2034
TESTNAME=""

source "${LIB_DIR}/lib.sh"

run -e "${TEST_DIR}/test-setup.sh"

run -e "${TEST_DIR}/test-gk-deploy.sh"

#run "${TEST_DIR}/test-dynamic-provisioning.sh"

#run "${TEST_DIR}/test-teardown.sh"
