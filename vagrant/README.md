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
cache. This allows you to reuse those caches on subsequent provisioning of the
VMs, and it is intended to help situations where one is developing in an
environment where they would rather not have to redownload many megabytes
repeatedly, e.g. hotel WiFi. :)  It stores the cache as a `tgz` file in your
`VAGRANT_HOME` directory, `~/.vagrant.d` by default. To enable this, either
specify `VAGRANT_CACHE=1` on the command line or change the `CACHE` variable
near the top of the Vagrantfile from `false` to `true`.

**CUSTOM REGISTRY:** Similar to the caching feature, this environment supports
interaction with a custom Docker registry. The idea is that a registry would
be running in a local environment somewhere that could be used as a primary
source for pulling container images into the VMs. Just specify the variable
`custom_registry` in the `global_vars.yml` file to configure it. The following
scripts are available to facilitate this feature:

 * `docker-registry-run.sh`: A simple script to run a Docker registry in a
   container on your local machine, listening on port 5000. **NOTE:** You may
   need to open up the relevant firewall port on your local machine.
 * `docker-cache.sh`: This script will detect all current images on a given VM
   (default 'master') and push each image to the custom registry. Usage:
   ```
   ./docker-cache.sh 192.168.121.1:5000 master
   ```

A typical workflow to start using this would look like:

 1. Run `docker-registry-run.sh`.
 2. Enable the custom registry in `global_vars.yml`.
    * **NOTE:** Since the registry is currently empty, any search for container
      images will proceed to the next registry (Docker Hub, by default).
 3. Start the vagrant environment: `up.sh`
 4. Run `docker-cache.sh <host IP>:5000 master`
 5. Run `docker-cache.sh <host IP>:5000 node0`
    * **OPTIONAL:** Run `docker pull gcr.io/google_containers/nginx-slim:0.8`
      on `node0` before caching, since it is used in testing.

Now Docker will check your custom registry before pulling from Docker Hub.
