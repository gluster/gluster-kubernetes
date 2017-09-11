#!/bin/bash

if [[ "${*}" == *"get "* ]]; then
	while [[ "${1}" != "get" ]]; do
		shift
	done
	shift
	restype="${1}"
	shift
	while [[ "${1}" != --selector* ]] && [[ "${1}" == --* ]]; do
		shift
	done
	select="${1}"
	if [[ "${restype}" == namespace* ]] && [[ "${select}" == "invalid" ]]; then
		echo "Error"
	fi
elif [[ "${*}" == *" config get-contexts" ]]; then
	if [[ "${0}" == *oc* ]]; then
		echo "* two three four storage"
	fi
fi

exit 0
