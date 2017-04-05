# Testsuite

This contains the testsuite for gluster-kubernetes.

## Prerequisites

The yaml tests require the 'yamllint' program.
Install it with e.g.

* `dnf install yamllint`, or
* `pip install yamllint`

The gk-deploy test uses ShellCheck if installed.
Install with

* `dnf install ShellCheck`, or
* `apt-get install shellcheck`

## TODOs

* Write more tests
* More elaborate basic tests need fuller mocking/stubbing of tools
* Write full functional tests to be run in vms
 (like the kubernetes vagrant environment)

