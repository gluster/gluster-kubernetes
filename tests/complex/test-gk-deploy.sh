#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"

source "${LIB_DIR}/lib.sh"

ssh_config || fail "ERROR to creating ssh-config"

copy_deploy || fail "ERROR copying deployment files"

run_on_node "${TEST_DIR}/test-inside-gk-deploy.sh" master || fail

pass
