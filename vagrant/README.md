# Overview
Kubernetes on CentOS 7 based on [kubeadm](http://kubernetes.io/docs/admin/kubeadm/).
Default setup is a single master with three nodes

To setup type:

```bash
$ ./up.sh
$ vagrant ssh master
[vagrant@master]$ kubectl get nodes
```

Works in Vagrant/Ansible on Linux with libvirt/KVM or on Mac OS X on Virtualbox

## Versions
Currently it uses Kubernetes v1.6.1

## Features

**CACHING:** This vagrant/ansible environment allows for caching of the yum
cache and Docker images. This allows you to reuse those caches on subsequent
provisioning of the VMs, and it is intended to help situations where one is
developing in an environment where they would rather not have to redownload
many megabytes repeatedly, e.g. hotel WiFi. :)  It stores both as `tgz` files
in your `VAGRANT_HOME` directory, `~/.vagrant.d` by default. To enable this,
either specify `VAGRANT_CACHE=1` on the command line or change the `CACHE`
variable near the top of the Vagrantfile from `false` to `true`. **NOTE:** This
will enable use of a Docker cache, but you must run `./docker_gen_cache.sh`
from the `vagrant/` directory to initialize the cache. This is because
creating the cache can take some time. It is recommended you pull any
additional images you use to the master node, as this cache will be used by all
nodes. For convenience, the GlusterFS and heketi images are automatically
pulled to the master node.
