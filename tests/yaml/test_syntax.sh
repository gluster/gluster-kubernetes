#!/bin/bash

SCRIPT_DIR=$(cd $(dirname ${0}); pwd)
TESTS_DIR="${SCRIPT_DIR}/.."
INC_DIR="${TESTS_DIR}/common"
BASE_DIR="${SCRIPT_DIR}/../.."
DEPLOY_DIR="${BASE_DIR}/deploy"
KTD="${DEPLOY_DIR}/kube-templates"
OTD="${DEPLOY_DIR}/ocp-templates"

KGDY="${KTD}/glusterfs-daemonset.yaml"
KHDY="${KTD}/heketi-deployment.yaml"
KHSY="${KTD}/heketi-service-account.yaml"
OGTY="${OTD}/glusterfs-template.yaml"
OHTY="${OTD}/heketi-template.yaml"
OHSY="${OTD}/heketi-service-account.yaml"

FAULTY_YAML="${SCRIPT_DIR}/glusterfs-daemonset-wrong.yaml"

source "${INC_DIR}/subunit.sh"

check_yaml () {
	local yaml=${1}
	yamllint -f parsable -d relaxed ${yaml}
}

check_invalid_yaml () {
	check_yaml ${1}
	if [ "x$?" = "x0" ]; then
		echo "ERROR: parsing invalid yaml succeeded"
		return 1
	fi

	return 0
}

failed=0

testit "check invalid yaml" \
	check_invalid_yaml ${FAULTY_YAML} \
	|| failed=$((failed + 1))

for yaml in ${KGDY} ${KHDY} ${KHSY} ${OGTY} ${OHTY} ${OHSY} ; do
	testit "check $(basename ${yaml})" \
		check_yaml ${yaml} \
		|| failed=$((failed + 1))
done

testok $0 ${failed}
