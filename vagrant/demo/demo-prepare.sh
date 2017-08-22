#!/bin/bash

DEMO_DIR="$(cd "$(dirname "${0}")" && pwd)"
VAGRANT_DIR="${DEMO_DIR}/.."
DEPLOY_DIR="${VAGRANT_DIR}/../deploy"
SSH_CONFIG="${DEMO_DIR}/ssh-config"

cd "${VAGRANT_DIR}" || exit 1

./up.sh

vagrant ssh-config > "${SSH_CONFIG}"

scp -r -F "${SSH_CONFIG}" "${DEPLOY_DIR}" master:

for NODE in node0 node1 node2 ; do
	ssh -t -F "${SSH_CONFIG}" "${NODE}" "sudo docker pull gcr.io/google_containers/nginx-slim:0.8"
done

"${DEMO_DIR}/demo-inside-wrapper.sh" "${DEMO_DIR}/demo-inside-prepare.sh"
