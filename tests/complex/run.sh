#!/bin/bash

# shellcheck disable=SC2034
TESTNAME=""
TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

run -e "${TEST_DIR}/test-setup.sh"

run -e "${TEST_DIR}/run-basic.sh"

run "${TEST_DIR}/test-teardown.sh"
