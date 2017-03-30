# OpenShift development environment

This vagrant-ansible script creates a setup in which you can run gk-deploy.
It creates five VMs (client, master, atomic0, atomic1, atomic2) with three
drives each.  The ansible script installs OpenShift on the master and
atomic systems.  The client machine can be used to run gk-deploy.

# Prerequisites

* You will need libvirt, Vagrant, and Ansible installed on your system.
* 12 GB of RAM or more are suggested.

# Setup

* type: `./up.sh`. Depending on your system setup, you may also have to specify `./up.sh --provider=libvirt` or `sudo ./up.sh --provider=libvirt`.
Note: For all subsequent operations, use vagrant commands like `vagrant halt` and
`vagrant up` instead of `up.sh`. The provisioner is not idempotent.

* Log into the client and get the status of the cluster

```
$ vagrant ssh client
[vagrant@client]$ oc status
```

* play with gk-deploy:

```
$ vagrant ssh client
[vagrant@client]$ cd deploy
[vagrant@client deploy]$ ./gk-deploy -g ../topology.json
```

