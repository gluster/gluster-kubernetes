#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

destroy_vagrant
