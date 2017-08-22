#!/bin/bash

# shellcheck disable=SC2034
TESTNAME=""
TEST_DIR="$(realpath "$(dirname "${0}")")"

source "${TEST_DIR}/lib.sh"

run -e "${TEST_DIR}/test-setup.sh"

run -e "${TEST_DIR}/test-gk-deploy.sh"

run "${TEST_DIR}/test-dynamic-provisioning.sh"

run "${TEST_DIR}/test-teardown.sh"
