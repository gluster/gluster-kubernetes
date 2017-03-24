# Kubernetes Demo Scripts

These demos can be run on the Kubernetes test environment
after bringing it up with `up.sh`. The `-inside-` scripts
are to be run in the VMs. You should run the wrapping
demo scripts:

* `demo-prepare.sh` : some preparations
* `demo-status.sh` : a status demo that can be run at any time
* `demo-deploy.sh` : demo `gk-deploy`
* `demo-test-heketi.sh` : demo heketi after gk-deploy
* `demo-dynamic-provisioning.sh` : dynamic provisioning with a simple nginx app
