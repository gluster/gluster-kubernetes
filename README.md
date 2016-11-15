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

### Demo

**>>> [Click here for a demo of the
technology!](https://drive.google.com/file/d/0B667S2caJiy7QVpzVVFNQVdyaVE/view?usp=sharing) <<<**






### Documentation

* [Setup Guide](./docs/setup-guide.md)
