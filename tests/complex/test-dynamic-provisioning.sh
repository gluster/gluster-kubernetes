#!/bin/bash

TEST_DIR="$(realpath "$(dirname "${0}")")"
DOCKER_IMAGE="gcr.io/google_containers/nginx-slim:0.8"

source "${TEST_DIR}/lib.sh"

pull_docker_image "${DOCKER_IMAGE}"

run -r master "${TEST_DIR}/test-inside-dynamic-provisioning.sh" "Test dynamic provisioning"
