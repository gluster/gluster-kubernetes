# gluster-kubernetes

## Hyper-converged GlusterFS + heketi on Kubernetes

**gluster-kubernetes** is a project to provide Kubernetes administrators a
mechanism to easily deploy a hyper-converged GlusterFS cluster along with with
heketi onto an existing Kubernetes cluster. This is a convenient way to unlock
the power of dynamically provisioned, persistent GlusterFS volumes in
Kubernetes.

### Component Projects

* **[Kubernetes](http://kubernetes.io/)**, the container management system.
* **[GlusterFS](https://www.gluster.org/)**, the scale-out storage system.
* **[heketi](https://github.com/heketi/heketi)**, the RESTful volume management
  interface for GlusterFS.

### Demo

**>>> [Video demo of the technology!](https://drive.google.com/file/d/0B667S2caJiy7QVpzVVFNQVdyaVE/view?usp=sharing) <<<**

### Documentation

* [Quickstart](#quickstart)
* [Setup Guide](./docs/setup-guide.md)
* [Hello World with GlusterFS Dynamic Provisioning](./docs/examples/hello_world/README.md)

### Quickstart

You can start with your own Kubernetes installation ready to go, or you can
use the vagrant setup in the `vagrant/` directory to spin up a Kubernetes
VM cluster for you. To run the vagrant setup, you'll need to have the
following installed:

 * ansible
 * vagrant
 * libvirt or VirtualBox

To spin up the cluster, simply run `./up.sh` in the `vagrant/` directory.

Next, copy the `deploy/` directory to the master node of the cluster.

You will have to provide your own topology file. A sample topology file is
included in the `deploy/` directory (default location that gk-deploy expects)
which can be used as the topology for the vagrant libvirt setup. When
creating your own topology file:

 * Make sure the topology file only lists block devices intended for heketi's
 use. heketi needs access to whole block devices (e.g. /dev/sdb, /dev/vdb)
 which it will partition and format.

 * The `hostnames` array is a bit misleading. `manage` should be a list of
 hostnames for the node, but `storage` should be a list of IP addresses on
 the node for backend storage communications.

If you used the provided vagrant libvirt setup, you can run:

```bash
$ vagrant ssh-config > ssh-config
$ scp -rF ssh-config ../deploy master:
$ vagrant ssh master
[vagrant@master]$ cd deploy
[vagrant@master]$ mv topology.json.sample topology.json
```

The following commands are meant to be run with administrative privileges
(e.g. `sudo su` beforehand).

For ease of use in the the vagrant setup, we recommend you run the following:

```bash
$ export KUBECONFIG="/etc/kubernetes/admin.conf"
```
At this point, verify the Kubernetes installation by making sure all nodes are
Ready:

```bash
$ kubectl get nodes
NAME      STATUS    AGE
master    Ready     22h
node0     Ready     22h
node1     Ready     22h
node2     Ready     22h
```

***NOTE***: To see the version of Kubernetes (which will change based on
latest official releases) simply do `kubectl version`. This will help in
troubleshooting.

For ease of use in the the vagrant setup, we recommend you run the following:

```bash
$ export KUBECONFIG="/etc/kubernetes/admin.conf"
```

Next, to deploy heketi and GlusterFS, run the following:

```bash
$ ./gk-deploy -g
```

If you already have a pre-existing GlusterFS cluster, you do not need the
`-g` option.

After this completes, GlusterFS and heketi should now be installed and ready
to go. You can set the `HEKETI_CLI_SERVER` environment variable as follows so
that it can be read directly by `heketi-cli` or sent to something like `curl`:

```bash
$ export HEKETI_CLI_SERVER=$(kubectl describe svc/heketi | grep "Endpoints:" | awk '{print "http://"$2}')

$ echo $HEKETI_CLI_SERVER
http://10.42.0.0:8080

$ curl $HEKETI_CLI_SERVER/hello
Hello from Heketi
```

Your Kubernetes cluster should look something like this:

```bash
$ kubectl get nodes,pods
NAME      STATUS    AGE
master    Ready     22h
node0     Ready     22h
node1     Ready     22h
node2     Ready     22h
NAME                               READY     STATUS              RESTARTS   AGE
glusterfs-node0-2509304327-vpce1   1/1       Running             0          1d
glusterfs-node1-3290690057-hhq92   1/1       Running             0          1d
glusterfs-node2-4072075787-okzjv   1/1       Running             0          1d
heketi-3017632314-yyngh            1/1       Running             0          1d
```

You should now also be able to use `heketi-cli` or any other client of the
heketi REST API (like the GlusterFS volume plugin) to create/manage volumes and
then mount those volumes to verify they're working. To see an example of how
to use this with a Kubernetes application, see the following:

[Hello World application using GlusterFS Dynamic Provisioning](./docs/examples/hello_world/README.md)
