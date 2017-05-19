# Gluster-Block Provisioning End-To-End Design

This design is the result of the work of several
people, most notably Humble Devassy Chirammal (@humblec),
who started an ealier draft of this end-to-end design
and gave many of the original ideas,
but also Luis Pabon (@lpabon) who is largely
responsible for an early cut at the heketi API,
Steve Watt (@wattsteve),
Vijay Bellur (@vbellur),
Pranith Kumar Karampuri (@pranithk),
and Prasanna Kumar Kalever (@pkalever).

## Motivation

While GlusterFS volumes can be used for RWO as well as RWX (and ROX) volumes,
that support is not complete and problematic in some regards:

1. RWO volumes should have protection from concurrent mounting.
  (Locking to a host.) This is currently not enforced by the GlusterFS
  mount plugin, hence the GlusterFS volumes may not meet the
  expectations of the users. (This could be enforced in the GlusterFS
  mount plugin, but there are more problems to solve.)
2. The performance of the GlusterFS file volumes does not match the expectations
  of many users who want to run dedicated workloads like databases and metrics
  on the RWO volumes.
  This is a fundamental problem in Gluster, because specifically metadata
  operations are slow due to the distributed/shared nature.
3. The scalability in the number of volumes that can be hosted is limited for
  GlusterFS volumes. But because the RWO volumes can't be shared, specifically
  for RWO we need a very good scalability. While the scalability in number
  of volumes is improving for GlusterFS volumes, we need a different level
  of scale.

For these reasons, we need better, or rather *proper* RWO support
that meets the above mentioned needs.

## Goals

The goal of the solution described in this design is to offer
proper RWO support for Kubernetes PVs backed by Gluster.
These improved RWO volumes should provide:

* better separation in the sense that a volume can only be mounted
  by one pod at a time.
* better performance specifically for metadata-heavy workloads.
* capability to scale to much larger numbers of volumes on one cluster.

This new type of gluster volumes should be provisioned dynamically
through storage classes.

## Basic Idea and Analysis

Use loopback files on GlusterFS volumes that are exported as block
devices via iSCSI. Attach to these iSCSI devices and mount them on
the Kubernetes nodes and bind-mount into the containers.

This introduces an additional layer of indirection to
file-system-access, so why would this be any faster?
While data operations are very fast with Gluster, the meta-data
operations are notoriously slow (GlusterFS being a distributed
file system). But with the iSCSI loopback approach, all meta-data
operations are translated into fast reads and writes.
So this approach adds a small penalty to I/O operations, but
gives a big speed-up to meta-data operations.

Gluster's resource consumption is mainly by GlusterFS volume.
Because this approach will use one gluster file volume to host
many loopback files, it will allow us to support a much larger
number of volumes with a given cluster and given hardware,
easily scaling to thousands and ten thousands of volumes.

A block device can not be used (R/W) by more than one
entity at a time without risking data corruption. Hence
for these RWO volumes, the single-mounter aspect needs to
be enforced.

## Components Involved

The components involved in the overall flow from kubernetes through
to gluster for this new functionality are:

* A new external (out-of-tree) kubernetes provisioner ```glusterblock```,
  to be exposed via a ```StorageClass```.
* Gluster's RESTful service interface Heketi
  with a new ```blockvolume``` set of subcommands to control the
  creation of block volumes.
* A new gluster tool ```gluster-block```, consisting of daemon component
  and a command line tool. This tool is responsible for creating the
  loopback files in a gluster volume and exporting them via iSCSI.
* The kubernetes iSCSI mount plugin.

## Overall Design and Flow

The high-level flow for requesting and using a gluster-block based volume
is as follows.

* Administrator creates a ```StorageClass``` referring to the ```glusterblock```
  provisioner.
* User requests a new ```RWO``` volume with a ```PersistentVolumeClaim``` (PVC).
* The ```glusterblock``` provisioner is invoked.
* The provisioner calls out to ```heketi``` with the request to create a gluster
  block volume with the requested characteristics like size, etc.
* ```heketi``` looks for an appropriate gluster volume in one of the suitable
  gluster clusters and calls out to ```gluster-block``` with the request to
  create a block volume on the specified gluster file volume.
* ```gluster-block``` creates a file on the gluster file volume and exports this
  as an iSCSI target.
* Upon success the resulting volume info (how to reach ...) is handed back
  all the way to the provisioner.
* The provisioner puts this volume information into a ```PersistentVolume```
  (PV) and sets it up to use the iSCSI mount plugin for mounting.
* The PV is bound to the original PVC.
* The user references the PVC in an application description.
* When the application pod is brought up on a node, the iSCSI mount plugin
  takes care of initiating the block device, formatting (if required) and
  mounting it.


## Details About The ```glusterblock``` Provisioner

The glusterblock provisioner is an external provisioner that is running in a
container. It's code is located in the ```gluster/block``` subdirectory of
<https://github.com/kubernetes-incubator/external-storage>.

The provisioner is mainly a simple translation engine that turns PVC requests
into requests for heketi via heketi's RESTful API, and wraps the resulting
volume information into a PV.

The provisioner is configured via a StorageClass which can look like this:

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: glusterblock
provisioner: gluster.org/glusterblock
parameters:
    resturl: "http://127.0.0.1:8081"
    restuser: "admin"
    secretnamespace: "default"
    secretname: "heketi-secret"
    hacount: "3"
    clusterid: "630372ccdc720a92c681fb928f27b53f"
```

The available parameters are:

* ```resturl```: how to reach heketi
* ```restuser```, ```secretnamespace```, ```secretname```:
  authentication information
* ```hacount``` (optional): How many paths to the target server to configure.
* ```clusterid``` (optional): List of one or more clusters to consider for
  finding space for the requested volume.

See  <https://github.com/kubernetes-incubator/external-storage/blob/master/gluster/block/README.md> for
additional and up-to-date details.

## Details About Heketi's New ```blockvolume``` Functionality

For the purposes of gluster block volumes, the same heketi instance is used
as for the regular glusterfs file volumes. Heketi has a new API though for
treating blockvolume requests. Just as with the glusterfs file volume
provisioning, the logic for finding suitable clusters and file volumes
for hosting the loopback files is part of heketi.

The API is a variation of the ```volume``` API and looks like this.

The supported functions are:

* ```BlockVolumeCreate```
* ```BlockVolumeInfo```
* ```BlockVolumeDelete```
* ```BlockVolumeList```

In the future, ```BlockVolumeExpand``` might get added.

### Note About The State Of The Implementation

As of 2017-06-23, a PR with the implementation is available
at <https://github.com/heketi/heketi/pull/793>.


### Details about the requests

#### BlockVolumeCreateRequest

The block volume create request takes the size and a name
and can optionally take a list of clusters and an hacount.

```
type BlockVolumeCreateRequest struct {
        Size       int       `json:"size"`
        Clusters   []string  `json:"clusters,omitempty"`
        Name       string    `json:"name"`
        Hacount    int       `json:"hacount,omitempty"`
        Auth       bool      `json:"auth,omitempty"
}
```

#### BlockVolume

This is the basic info about a block volume.

```
BlockVolume struct {
        Hosts     []string `json:"hosts"`
        Iqn       string   `json:"iqn"`
        Lun       int      `json:"lun"`
        Username  string   `json:"username"`
        Password  string   `json:"password"`
}

```

#### BlockVolumeInfo

This is returned for the blockvolume info request and
upon successful creation.

```
type BlockVolumeInfo struct {
        Size       int       `json:"size"`
        Clusters   []string  `json:"clusters,omitempty"`
        Name       string    `json:"name"`
        Hacount    int       `json:"hacount,omitempty"`
        Id         string    `json:"id"`
        Size       int       `json:"size"`
        BlockVolume struct {
                Hosts     []string `json:"hosts"`
                Hacount   int `json:"hacount"`
                Iqn       string `json:"iqn"`
                Lun       int `json:"lun"`
        } `json:"blockvolume"`
}

```


#### BlockVolumeListResponse

The block volume list request just gets a list
of block volume IDs as response.


```
type BlockVolumeListResponse struct {
        BlockVolumes []string `json:"blockvolumes"`
}

```

### Details About Heketi's Internal Logic

#### Block-hosting volumes

The loopback files for block volumes need to be stored in
gluster file volumes. Volumes used for gluster-block volumes
should not be used for other purposes. For want of a better
term, we call these volumes that can host block-volume
loopback files **block-hosting file-volumes** or (for brevity)
**block-hosting volumes** in this document.

#### Labeling block-hosting volumes

In order to satisfy a blockvolume create request, Heketi
needs to find and appropriate block-hosting volume in
the available clusters.  Hence heketi should internally
flag these volumes with a label (`block`).

#### Type of block-hosting volumes

The block-hosting volumes should be regular
3-way replica volumes (possibly distributed).
One important aspect is that for performance
reasons, sharding should be enabled on these volumes.

#### Block-hosting volume creation automatism

When heketi, upon receiving a blockvolume create request,
does not find a block-hosting volume with sufficient
space in any of the considered clusters, it would look for
sufficient unused space in the considered clusters and create
a new gluster file volume, or expand an existing volume
labeled `block`.

The sizes to be used for auto-creation of block-hosting
volumes will be subject to certain parameters that can
be configured and will have reasonable defaults:

* `auto_create_block_hosting_volume`: Enable auto-creation of
  block-hosting volumes?
  Defaults to **false**.
* `block_hosting_volume_size`: The size for a new block-hosting
  volume to be created on a cluster will be the minimum of the value
  of this setting and maximum size of a volume that could be created.
  This size will also be used when expanding volumes: The amount
  added to the existing volume will be the minimum of this value
  and the maximum size that could be added.
  Defaults to **1TB**.

#### Internal heketi db format for block volumes

Heketi stores information about the block volumes
in it's internal DB. The information stored is

* id: id of this block volume
* name: name given to the volume
* volume: the id of the block-hosting volume where the loopback file resides
* hosts: the target ips for this volume

#### Cluster selection

By default, heketi would consider all available clusters
when looking for space to create a new block-volume file.

With the clusters request parameter, this search can be
narrowed down to an explicit list of one or more clusters.
With the help of the ```clusterid``` storage class option,
this gives the kubernetes administrator a way to e.g. separate
different storage qualities, or to reserve a cluster
exclusively for block-volumes.


### Details On Calling ```gluster-block```

Heketi calls out to ```gluster-block``` the same way it
currently calls out to the standard gluster cli for the
normal volume create operations, i.e. it uses a kubexec
mechanism to run the command on one of the gluster nodes.
(In a non-kubernetes install, it uses ssh.)


## Details About ```gluster-block```

```gluster-block``` is the gluster-level tool to make creation
and consumption of block volumes very easy. It consists of
a server component ```gluster-blockd``` that runs on the gluster
storage nodes and a command line client utility ```gluster-block```
that talks to the ```gluster-blockd``` with local RPC mechanism
and can be invoked on any of the gluster storage nodes.

gluster-block takes care of creating loopback files on the
specified gluster volume. These volumes are then exported
as iSCSI targets with the help of the tcmu-runner mechanism,
using the gluster backend with libgfapi. This has the big
advantage that it is talking to the gluster volume directly
in user space without the need of a glusterfs fuse mount,
skipping the kernel/userspace context switches and the
user-visible mount altogether.

The supported operations are:

* create
* list
* info
* delete
* modify

Details about the gluster-block architecture can be found
in the gluster-block git repository <https://github.com/gluster/gluster-block>
and the original design notes
<https://docs.google.com/document/d/1psjLlCxdllq1IcJa3FN3MFLcQfXYf0L5amVkZMXd-D8/edit?usp=sharing>.


## Details About Using The In-Tree iSCSI Mount Plugin

The kubernetes in-tree iSCSI mount plugin is used by the PVs created
by the new glusterblock external provisioner. The tasks that are performed
when a user brings up an application pod using a corresponding glusterblock
PVC are:

* create /dev/sdX on the host (iscsi login / initiator)
* format the device if it is has not been formatted
* mount the file system on the host
* bind-mount the host mounted directory into the application pod

Multi-pathing support has been added to the iSCSI plugin so that
the gluster-block volumes are made highly availble with the ```hacount```
feature.

The iSCSI plugin has been changed in such a way that it does not allow
more than one concurrent R/W mount of an iscsi block device.
