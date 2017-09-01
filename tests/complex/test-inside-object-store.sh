#!/bin/bash

# test object store

S3_ID="${1}"
shift
S3_CMD="${1}"
shift
S3_CMD_ARGS=(${@})

BUCKET="bucket1"
OBJECT="hello.txt"
OBJECT_CONTENTS="Hello world!"

putbucket() {

  output=$(./s3curl.pl --debug --id "${S3_ID}" --put /dev/null -- -k -v "http://${S3_SVC}/${BUCKET}" 2>&1)
  if ! echo "${output}" | grep -q "HTTP/1.1 200"; then
    echo "${output}"
    exit 1
  fi

}

getbucket() {

  output=$(./s3curl.pl --debug --id "${S3_ID}" -- -k -v "http://${S3_SVC}/${BUCKET}" 2>&1)
  if ! echo "${output}" | grep -q "HTTP/1.1 200"; then
    echo "${output}"
    exit 1
  fi
  output=$(./s3curl.pl --id "${S3_ID}" -- -k -s "http://${S3_SVC}/${BUCKET}/" 2>&1)
  echo "${output}"

}

delbucket() {

  output=$(./s3curl.pl --debug --id "${S3_ID}" --delete -- -k -v "http://${S3_SVC}/${BUCKET}" 2>&1)
  if ! echo "${output}" | grep -q "HTTP/1.1 [204\|404]"; then
    echo "${output}"
    exit 1
  fi

}

putobject() {

  cat >"${OBJECT}" <<<"${OBJECT_CONTENTS}"
  output=$(./s3curl.pl --debug --id "${S3_ID}" --put ${OBJECT} -- -k -v "http://${S3_SVC}/${BUCKET}/${OBJECT}" 2>&1)
  if ! echo "${output}" | grep -q "HTTP/1.1 200"; then
    echo "${output}"
    exit 1
  fi

  objects=$(getbucket)
  if [[ "${objects}" != *${OBJECT}* ]]; then
    echo "Object '${OBJECT}' not found in bucket '${BUCKET}':"
    echo "${objects}"
    exit 1
  fi

  output=$(./s3curl.pl --id "${S3_ID}" -- -k -s "http://${S3_SVC}/${BUCKET}/${OBJECT}" 2>&1)
  if [[ "${output}" != "${OBJECT_CONTENTS}" ]]; then
    echo "Object contents don't match: '${output}' vs. '${OBJECT_CONTENTS}'"
    exit 1
  fi

}

delobject() {

  output=$(./s3curl.pl --debug --id "${S3_ID}" --delete -- -k -v "http://${S3_SVC}/${BUCKET}/${OBJECT}" 2>&1)
  if ! echo "${output}" | grep -q "HTTP/1.1 [204\|404]"; then
    echo "${output}"
    exit 1
  fi

}

clearbucket() {
  delobject
  delbucket
}

cd s3-curl || exit 1

S3_SVC=$(kubectl get svc/gluster-s3-service --template '{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}')

"${S3_CMD}" "${S3_CMD_ARGS[@]}"

exit 0
