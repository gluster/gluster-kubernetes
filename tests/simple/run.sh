#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

failed=0

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
		((failed+=rc))
	fi
done

exit ${failed}
