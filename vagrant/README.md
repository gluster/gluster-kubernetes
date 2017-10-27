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
Currently it uses Kubernetes v1.7.8

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

**GCR.IO PROXY:** An addition to the custom registry, this environment allows
you to set up an nginx proxy on the master node VM that can redirect gcr.io
traffic to your custom registry. This allows you to store any images from
gcr.io in your custom registry and then have things like kubeadm pull from
there instead of the actual gcr.io. Just specify `custom_registry_gcr=true` in
`global_vars.yml`. The `gcr-proxy-state.sh` script is available to set the
proxy redirect on or off at runtime.

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
 6. Tear down the vagrant environment: `vagrant destroy`
 7. Set `custom_registry_gcr=true` in `global_vars.yml`

Now Docker will pull gcr.io images and custom images from your custom registry,
and check your custom registry before pulling from Docker Hub. You will want to
periodically set `custom_registry_add=false` and `custom_registry_gcr=false` to
pull updated images and then cache them with `docker-cache.sh`.

**CUSTOM YUM REPOS:** As an alternative or complementary tool to the rpm caching
feature mentioned above, the `custom_yum_repos` variable can be enabled to
supply custom yum repos to the VMs. These custom repos can be used to cache
packages across multiple projects or inject custom RPMs into the VMs.

To configure it, uncomment or copy the `custom_yum_repos` variable in
`global_vars.yml`. Supply key-value pairs, where the key is the name of the
yum repository and the value is the repository's url. Example:
  ```
  custom_yum_repos:
    kubernetes_el7: http://mypkgs/path/to/repo1
    epel_el7: http://mypkgs/path/to/repo2
    gluster_el7: http://mypkgs/another/repo/path/repo3
  ```


**CUSTOM HOST ALIASES:** If you want or need to use a name for the yum
repository hosts or custom docker registry that does not resolve normally,
you can define a `custom_host_aliases` in `global_vars.yml`. This value takes
a list of items where each item is a mapping with the keys `addr`, an ip
address, and `names`, a list of host names. Example:
   ```
   custom_host_aliases:
     - addr: 192.168.122.164
       names:
         - myserver
         - myserver.localdomain
     - addr: 192.168.122.166
       names:
         - foo
         - foo.example.org
   ```
