#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"
LIB_DIR="${TEST_DIR}"

source "${LIB_DIR}/lib.sh"

create_vagrant || fail "ERROR creating vagrant environment"

pass
