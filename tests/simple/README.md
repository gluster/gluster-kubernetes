# Testsuite - simple tests

This directory contains simple tests for gluster-kubernetes.
These are tests that do not test the full stack end-to-end
but are syntax-checks or unit-tests, or use mocking or stubbing
to test specific aspects.

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

