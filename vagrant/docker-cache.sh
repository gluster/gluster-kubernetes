#!/bin/bash

REGISTRY=${1}
MACHINE=${2:-master}
IMAGES=$(vagrant ssh "${MACHINE}" -c "sudo -s -- docker images --format \"{{.Repository}} {{.Tag}}\"" -- -q | tr "[:cntrl:]" "\n")

while read -r IMAGE; do
  if [[ "$IMAGE" == "" ]]; then continue; fi
  REPO=$(echo "$IMAGE" | cut -f1 -d " " -)
  NAME=${REPO#[^/]*/}
  TAG=$(echo "$IMAGE" | cut -f2 -d " " -)
  if [[ "${TAG}" == "<none>" ]]; then
    TAG=""
  else
    TAG=":${TAG}"
  fi
  if [[ "${REPO}" != *${REGISTRY}* ]]; then
    echo "Tagging $NAME$TAG"
    vagrant ssh "${MACHINE}" -c "sudo docker tag ${REPO}${TAG} ${REGISTRY}/${NAME}${TAG}" -- -qn
    echo "Pushing $NAME$TAG"
    vagrant ssh "${MACHINE}" -c "sudo docker push ${REGISTRY}/${NAME}${TAG}" -- -qn
  fi
done <<< "$IMAGES"
