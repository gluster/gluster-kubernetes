#!/bin/bash

TEST_DIR="$(realpath $(dirname $0))"

source "${TEST_DIR}/lib.sh"

create_vagrant || fail "ERROR creating vagrant environment"

pass
