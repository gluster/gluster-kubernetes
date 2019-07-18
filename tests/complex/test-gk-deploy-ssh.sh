#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

copy_deploy

install_gluster

run -r master -e "${TEST_DIR}/test-inside-gk-deploy.sh block obj ssh" "Test full SSH deployment"

run -r master "${TEST_DIR}/test-inside-gk-deploy.sh block obj ssh" "Test full SSH deployment idempotence"
