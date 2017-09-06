# Test suite - complex tests for gluster-kubernetes

These tests are complex, end-to-end functional tests using
our vagrant based test environment.

## Running

`./run.sh` will run a basic set of tests. The tests can
also be run individually like

```
./test-setup.sh
./test-gk-deploy.sh
```

and at a later time:

```
./test-dynamic-provisioning.sh
```

There are additional test runs available which require that
the vagrant environment be setup (e.g. `test-setup.sh`)
before each run:

* `run-basic.sh`: Test basic deployment and functionality
* `run-object.sh`: Test gluster-s3 deployment

Running `run-all.sh` will go through all test runs, rolling
back the vagrant environment between each run.

## Environment variables

There are various environment variables that can be
overridden, so that this can run for instance against
a different vagrant environment. E.g. if you have
already brought up a vagrant environment manually,
you could from the vagrant-dir do:

```
export VAGRANT_DIR=$(realpath ./)
../tests/functional/test-gk-deploy.sh
```

All variables:
- `BASE_DIR`
- `TEST_DIR`
- `DEPLOY_DIR`
- `VAGRANT_DIR`
- `TOPOLOGY_FILE`

If you override these, then you should provide absolute paths.
