#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
DOCKER_IMAGE="gcr.io/google_containers/nginx-slim:0.8"

source "${TEST_DIR}/lib.sh"

ssh_config || fail "ERROR creating ssh config"

pull_docker_image "${DOCKER_IMAGE}" || fail "ERROR pulling nginx docker images"

run_on_node "${TEST_DIR}/test-inside-dynamic-provisioning.sh" master || fail

pass
run -r master "${TEST_DIR}/test-inside-dynamic-provisioning.sh" "Test dynamic provisioning"
