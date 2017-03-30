#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"

source "${LIB_DIR}/lib.sh"

ssh_config || fail "ERROR creating ssh config"

pull_docker_image || fail "ERROR pulling docker images"

run_on_node "${TEST_DIR}/test-inside-dynamic-provisioning.sh" master || fail

pass
