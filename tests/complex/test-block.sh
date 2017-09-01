#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"

source "${TEST_DIR}/lib.sh"

run -r master -e "${TEST_DIR}/test-inside-block.sh" "Testing block storage"
