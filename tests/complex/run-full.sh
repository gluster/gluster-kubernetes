#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

run -e "${TEST_DIR}/test-gk-deploy-full.sh"

run "${TEST_DIR}/test-dynamic-provisioning.sh"

run "${TEST_DIR}/test-block.sh"

run "${TEST_DIR}/test-object-store.sh"
