#!/bin/bash

TEST_DIR="$(realpath "$(dirname "${0}")")"

source "${TEST_DIR}/lib.sh"

copy_deploy

run -r master -e "${TEST_DIR}/test-inside-gk-deploy.sh" "Test basic deployment"

run -r master "${TEST_DIR}/test-inside-gk-deploy.sh" "Test basic deployment idempotence"

