#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

run -e "${TEST_DIR}/test-gk-deploy.sh"

run "${TEST_DIR}/test-dynamic-provisioning.sh"
