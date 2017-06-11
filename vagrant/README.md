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
