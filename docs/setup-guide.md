# Setup Guide

This guide contains detailed instructions for deploying GlusterFS + heketi onto
Kubernetes.

## Infrastructure Requirements

The only strict requirement is a pre-existing Kubernetes cluster and
administrative access to that cluster. You can opt to deploy GlusterFS as a
hyper-converged service on your Kubernetes nodes if they meet the following
requirements:

 * There must be at least three nodes.

 * Each node must have at least one raw block device attached (like an EBS
 Volume or a local disk) for use by heketi. These devices must not have any
 data on them, as they will be formatted and partitioned by heketi.

 * Each node must have the following ports opened for GlusterFS communications:

  * 2222 - GlusterFS pod's sshd

  * 24007 - GlusterFS Daemon

  * 24008 - GlusterFS Management

  * 49152 to 49251 - Each brick for every volume on the host requires its own
  port. For every new brick, one new port will be used starting at 49152. We
  recommend a default range of 49152-49251 on each host, though you can
  adjust this to fit your needs.

 * Each node requires that the `mount.glusterfs` command is available. Under
  all Red Hat-based OSes this command is provided by the `glusterfs-fuse`
  package.

If you are not able to deploy a hyper-converged GlusterFS cluster, you must
have one running somewhere that the Kubernetes nodes can access. The above
requirements still apply for any pre-existing GlusterFS cluster.

## Deployment Overview

An administrator must provide the topology information of the GlusterFS cluster
to be accessed by heketi. The majority of the deployment tasks are handled by
the [gk-deploy](../deploy/gk-deploy) script. The following is an overview of
the steps taken by the script:

1. Creates a Service Account for heketi to securely communicate with the
   GlusterFS nodes.
2. As an option, deploys GlusterFS as a
   [DaemonSet](http://kubernetes.io/docs/admin/daemons/) onto the Kubernetes
   nodes specified in the topology.
3. Deploys an instance of heketi called 'deploy-heketi', which is used to
   initialize the heketi database.
4. Creates the Service and Endpoints for communicating with the GlusterFS
   cluster and initializes the heketi database by creating a GlusterFS volume,
   then copies the database onto that same volume for use by the final
   instance of heketi.
5. Deletes all the 'deploy-heketi' related resources.
6. Deploys the final instance of the heketi service.

## Deployment

### 1. Create a topology file

As mentioned in the overview, an administrator must provide the GlusterFS
cluster topology information. This takes the form of a topology file, which
describes the nodes present in the GlusterFS cluster and the block devices
attached to them for use by heketi. A
[sample topology file](../deploy/topology.json.sample) is provided. When
creating your own topology file:

 * Make sure the topology file only lists block devices intended for heketi's
 use. heketi needs access to whole block devices (e.g. /dev/sdb, /dev/vdb)
 which it will partition and format.

 * The `hostnames` array is a bit misleading. `manage` should be a list of
 hostnames for the node, but `storage` should be a list of IP addresses on
 the node for backend storage communications.

### 2. Run the deployment script

Next, run the [gk-deploy](../deploy/gk-deploy) script from a machine with
administrative access to your Kubernetes cluster. You should familiarize
yourself with the script's options by running `gk-deploy -h`. Some things to
note when running the script:

 * By default it expects the topology file to be in the same directory as
 itself. You can specify a different location as the first non-option
 argument on the command-line.

 * By default it expects to have access to Kubernetes template files in a
 subdirectory called `kube-templates`. Specify their location otherwise
 with `-t`.

 * By default it will NOT deploy GlusterFS, allowing you to use heketi with
 any existing GlusterFS cluster. If you specify the `-g` option, it will
 deploy a GlusterFS DaemonSet onto your Kubernetes cluster by treating the
 nodes listed in the topology file as hyper-converged nodes with both
 Kubernetes and storage devices on them.

  * If you use a pre-existing GlusterFS cluster, please note that any
  pre-existing volumes will not be detected by heketi, and thus not be under
  heketi's management.

# Usage Examples

Running the following from a node with Kubernetes administrative access and
[heketi-cli](https://github.com/heketi/heketi/releases) installed creates a
100GB Persistent Volume
[which can be claimed](http://kubernetes.io/docs/user-guide/persistent-volumes/#claims-as-volumes)
from any application:

```
$ export HEKETI_CLI_SERVER=http://<address to heketi service>
$ heketi-cli volume create --size=100 \
  --persistent-volume \
  --persistent-volume-endpoint=heketi-storage-endpoints | kubectl create -f -
```

You will also find a [sample application](./examples/hello_world) shipped as
part of this documentation.
