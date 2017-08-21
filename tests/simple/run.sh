#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "${0}")")"

for testdir in ${SCRIPT_DIR}/*; do
	if [[ ! -d ${testdir} ]]; then
		continue
	fi

	if [[ ! -x ${testdir}/run.sh ]]; then
		continue
	fi

	pushd "${testdir}"
	./run.sh
	rc=${?}
	popd

	if [[ ${rc} -ne 0 ]]; then
		exit 1
	fi
done
