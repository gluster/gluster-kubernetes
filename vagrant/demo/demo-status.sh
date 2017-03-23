#!/bin/bash

DEMO_DIR="$(cd $(dirname $0) ; pwd)"
VAGRANT_DIR="${DEMO_DIR}/.."
DEPLOY_DIR="${VAGRANT_DIR}/../deploy"

SSH_CONFIG=${DEMO_DIR}/ssh-config

cd ${VAGRANT_DIR}

${DEMO_DIR}/demo-inside-wrapper.sh ${DEMO_DIR}/demo-inside-status.sh
