#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

run -e "${TEST_DIR}/test-gk-deploy-object.sh"

run "${TEST_DIR}/test-object-store.sh"
