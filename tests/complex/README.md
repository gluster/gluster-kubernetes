# Test suite - complex tests for gluster-kubernetes

These tests are complex, end-to-end functional tests using
our vagrant based test environment.

## Running

`./run.sh` will run all the tests. But the tests
can also be run individually like

```
./test-setup.sh
./test-gk-deploy.sh
```

and at a later time:

```
./test-dynamic-provisioning.sh
```

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

If you override these, then you should provide absolute paths.
