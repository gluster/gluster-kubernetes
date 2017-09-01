#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

copy_deploy

run -r master -e "${TEST_DIR}/test-inside-gk-deploy.sh obj" "Test object deployment"

run -r master "${TEST_DIR}/test-inside-gk-deploy.sh obj" "Test object deployment idempotence"
