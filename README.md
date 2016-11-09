# gluster4kube

## persistent storage for kubernetes with gluster

This is the home of the **gluster4kube** project (working name),
a new project which brings dynamically provisioned persistent
storage volumes to kubernetes, using a hyperconverged Gluster
deployment scheme.

The components in this project are:

* **kubernetes** (https://github.com/kubernetes/kubernetes/), the container management system.
* **Glusterfs** (https://www.gluster.org/), the scale-out storage system, running as pods inside the kubernetes cluster.
* **heketi** (https://github.com/heketi/heketi), Gluster's volume management service interface, running in a pod inside kubernetes.


