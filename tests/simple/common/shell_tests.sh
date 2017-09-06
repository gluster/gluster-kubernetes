test_shell_syntax() {
	bash -n "${1}"
}

test_shellcheck() {
	if ! which shellcheck ; then
		echo "ShellCheck not found: skipping..."
		return 0
	fi

	shellcheck -x -s bash -e SC2181,SC2029,SC1091,SC1090 "${1}"
}

test_real_path() {
	grep -s "[r]ealpath" "${1}"
	if [[ ${?} -eq 0 ]]; then
		return 1
	else
		return 0
	fi
}
