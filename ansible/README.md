# Ansible Deployment

Ansible can help streamline the deployment of **gluster-kubernetes** to an existing OpenShift or Kubernetes cluster.  The ansible `deploy.yaml` playbook does this by installing the required package dependencies, loading the required kernel modules, and running the `gk-deploy` script.  If you do not already have a working cluster with storage added to the nodes, please refer back to the main documenation.

## Supported Deployments

Currently, the following Operating Systems are supported:

- Ubuntu 16.04

## Setup

To get started, make sure [ansible is installed](http://docs.ansible.com/ansible/intro_installation.html) on your local machine and that you have SSH connectivity between your machine and each node in the cluster.  You will then need to manually create two files: `inventory.ini` and `topology.json`.

### inventory.ini

Copy and modify the sample inventory file `inventory.ini.sample`.  This file will be referenced when running the ansible playbooks.

### topology.json

See the [Setup Guide](../docs/setup-guide.md#1-create-a-topology-file) for more information on the topology file.  The `topology.json` file should still be placed in the root project's deploy directory.

## Deploy Playbook

Before deploying, first review and edit any config parameters in `group_vars/all.yaml`.  You can then execute the playbook with:

```
cd ansible/
ansible-playbook -i inventory.ini deploy.yaml
```

### Ansible Role Overview

The deploy.yaml playbook uses several Ansible roles:

1. **bootstrap**: Prepares the target server for further ansible execution by installing python if needed.
2. **build-heketi**: Checks out [heketi](https://github.com/heketi/heketi) project source and builds heketi on the master node. The master needs the built `heketi-cli` binary to communicate with the deployed heketi pod. TODO: Alternatively, we could grab the binary releases but building from source is useful for targets with uncommon architectures, see heketi/heketi#627.
3. **gk-prep**: Installs glusterfs-client 3.8 and loads required dm_* kernel modules.
4. **gk-deploy**: Copies serval files including the gk-deploy script, k8s/ocp templates, and topology file.  It then runs the gk-deploy script with the -g flag to install a GlusterFS cluster.
5. **gk-post**: Automatically finds the HEKETI_SERVER_CLI and creates the StorageClass under a user-configured name from group_vars/all.yml.

## Abort Playbook

Runs gk-deploy with --abort. It also removes the StorageClass.

`ansible-playbook -i inventory.ini abort.yaml`

## Destroy Volume Groups Playbook

Lists the glusterfs volume groups on each node and then after a user confirmation prompt, the playbook deletes them using `vgremove`.

`ansible-playbook -i inventory.ini destroy_vgs.yaml`

Often during testing when you want to destroy the volume groups, you will likely want to do that at the same time as aborting the deployment.  You can run both abort and deploy playbooks sequentially with:

`ansible-playbook -i inventory.ini abort.yaml destroy.yaml`
