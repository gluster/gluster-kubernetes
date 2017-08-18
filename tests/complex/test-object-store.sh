#!/bin/bash

TEST_DIR="$(cd "$(dirname "${0}")" && pwd)"
S3CURL_URL="http://s3.amazonaws.com/doc/s3-example-code/s3-curl.zip"
S3_ACCOUNT="account"
S3_USER="user"
S3_PASSWORD="password"

source "${TEST_DIR}/lib.sh"

run -r master -e "${TEST_DIR}/test-inside-object-store-setup.sh ${S3CURL_URL} ${S3_ACCOUNT} ${S3_USER} ${S3_PASSWORD}" "Setup s3curl"

run -r master -e "${TEST_DIR}/test-inside-object-store.sh ${S3_ACCOUNT}:${S3_USER} clearbucket" "Clear bucket"

run -r master -e "${TEST_DIR}/test-inside-object-store.sh ${S3_ACCOUNT}:${S3_USER} putbucket" "Test put of bucket"

run -r master "${TEST_DIR}/test-inside-object-store.sh ${S3_ACCOUNT}:${S3_USER} putobject" "Test put of object"

run -r master "${TEST_DIR}/test-inside-object-store.sh ${S3_ACCOUNT}:${S3_USER} delobject" "Test delete of object"

run -r master "${TEST_DIR}/test-inside-object-store.sh ${S3_ACCOUNT}:${S3_USER} delbucket" "Test delete of bucket"
