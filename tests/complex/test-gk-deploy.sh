#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"

source "${LIB_DIR}/lib.sh"

ssh_config

copy_deploy

run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh" master "Greenfield basic deployment" || exit 1

run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh" master "Test deployment idempotence"

rollback_vagrant

run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh block" master "Block deployment"

#run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh block" master "Idempotent block deployment"

#run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh obj" master "S3 deployment"

#run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh obj" master "Idempotent S3 deployment"
