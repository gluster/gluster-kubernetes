# gluster-kubernetes

## Dynamic, persistent storage for Kubernetes with GlusterFS

This is the home of the **gluster-kubernetes** project,
a new project which brings dynamically provisioned persistent
storage volumes to kubernetes, using a hyperconverged Gluster
deployment scheme.

### The components in this project are:

* **Kubernetes** (https://github.com/kubernetes/kubernetes/), the container management system.
* **GlusterFS** (https://www.gluster.org/), the scale-out storage system, running as pods inside the kubernetes cluster.
* **heketi** (https://github.com/heketi/heketi), Gluster's volume management service interface, running in a pod inside kubernetes.

### Quickstart

You can start with your own Kubernetes installation ready to go, or you can
use the vagrant setup in the `vagrant/` directory to spin up a Kubernetes
VM cluster for you. To run the vagrant setup, you'll need to have the
following installed:

 * ansible
 * vagrant
 * libvirt or VirtualBox

To spin up the cluster, simply run `./up.sh` in the `vagrant/` directory.

Next, copy the `deploy/` directory to the master node of the cluster. If you
used the provided vagrant setup, first run:

```bash
$ export KUBECONFIG="/etc/kubernetes/admin.conf"
```

Next, to deploy heketi, run:

```bash
$ ./gk-deploy -g
```

If you already have GlusterFS deployed in your cluster, you do not need the
`-g` option.

heketi should now be installed and ready to go. For ease of testing, we
recommend the following:

```bash
$ export HEKETI_CLI_SERVER=$(kubectl describe svc/heketi | grep "Endpoints:" | awk '{print "http://"$2}')
```

You should now be able to use `heketi-cli` to create volumes and then mount
those volumes to verify they're working.

### Demo

**>>> [Video demo of the technology!](https://drive.google.com/file/d/0B667S2caJiy7QVpzVVFNQVdyaVE/view?usp=sharing) <<<**


### Documentation

* [Setup Guide](./docs/setup-guide.md)
