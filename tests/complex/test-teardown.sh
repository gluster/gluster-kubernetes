#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"

source "${TEST_DIR}/lib.sh"

destroy_vagrant
