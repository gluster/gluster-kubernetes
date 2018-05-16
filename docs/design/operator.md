# Gluster Operator 1.0 Design

## Introduction

This document specifies the overall design for a Gluster operator. An operator
is a Kubernetes [controller](https://github.com/kubernetes/sample-controller)
that is focused on managing a specific application with the goal of automating
common tasks that an administrator would typically perform.

This document is a formalization of many hours of discussion by several people.
Credit and thanks to Humble Devassy Chirammal (@humblec),Steve Watt
(@wattsteve), and John Strunk (@JohnStrunk) for their early and insightful
contributions to the discussions.

This document aims to settle on a concrete set of functionality that a Gluster
operator should have. It is outside the scope of this document to specify any
implementation details of this functionality. The desired functionality should
not be strictly limited by the extents of current-day technologies but should
not dismiss the costs of waiting for and executing forward development in those
technologies.

In addition, this document only specifies the desired functionality for
declaring a 1.0 release. Further enhancements and feature roadmaps will be
captured elsewhere.

### Motivation

The Gluster operator aims to further streamline the experience of deploying and
maintaining Gluster clusters for use in a Kubernetes environment. It will
achieve this through the use of common Kubernetes components and paradigms,
helping further integrate persistent storage into the Kubernetes experience.

## Configurations

The Gluster operator will be capable of managing a number of configurations of
Gluster clusters. Gluster's flexibility allows it to run in many types of
environments and the operator will aim to preserve that flexibility as much as
possible.

### External Deployments

External deployments are those in which the Gluster servers are not running as
containers inside Kubernetes. They are running on external, potentially
dedicated, storage nodes.

### Hosted Deployments

Hosted deployments are those in which the Gluster servers are running as
containers but their storage devices are not managed by the operator. In these
deployments, an administrator is required to maintain any underlying storage
devices and inform the operator as to any changes in their configuration.

### Managed Deployments

Managed deployments are those in which the Gluster servers are running as
containers and their storage devices are managed by the operator. These
deployments are designed for cloud environments where storage devices can be
provisioned programmatically.

## Features

Since the Gluster operator will support a variety of deployment configurations,
it will not be feasible to provide identical feature sets across all
configurations. The following sections note which features will be available to
which configuration.

All operational features will be designed to be as idempotent as possible. It is
acknowledged that this may not be immediately possible due to restrictions in
the underlying technology but an effort will still be made.

### Deployment

The Gluster operator will be able to deploy a new Gluster cluster using a set of
configuration parameters. This configuration will allow for extensive
customization if desired but will assume sane defaults for as many parameters as
possible to allow for as minimal a configuration as possible.

**Target Configurations:** Hosted, Managed

### Upgrade

The Gluster operator will be able to execute a rolling upgrade of any hosted or
managed Gluster cluster. It will trigger an upgrade one node at a time, waiting
for the node to come up and for the cluster to report no pending heals to any
files before triggering a subsequent node.

**Target Configurations:** Hosted, Managed

### Event Monitoring

The Gluster operator will watch for events on various aspects of the clusters it
will automate.

#### Storage Capacity

The Gluster operator will monitor the storage capacity of the overall cluster.
Storage capacity is defined here as the amount of space that can be committed to
new Gluster volumes and not how much free space is available. It will trigger
events when storage capacity reaches "Warning" levels and "Critical" levels.
These levels will be configurable, and should be set to a value that will allow
for corrective action to take place before the storage reaches maximum capacity.

**Target Configurations:** External, Hosted, Managed

#### Volume Density

The Gluster operator will monitor the total volume density of any cluster it is
automating. It will trigger events when the number of volumes in the cluster
reaches a pre-defined level that should prompt corrective action. This value
will be configurable, and should be set to a value that will allow for
corrective action to take place before cluster nodes lag or crash.

**Target Configurations:** External, Hosted, Managed

#### Device Health

The Gluster operator will monitor the health of all devices in an automated
Gluster cluster. It will report a "Warning" when a device reports failing health
and will report a "Critical" problem when a device becomes inaccessible. Support
for this feature may vary form one device type to another.

**Target Configurations:** External, Hosted, Managed

#### Volume Health

The Gluster operator will monitor the health of all volumes in an automated
Gluster cluster. It will report a "Warning" when a volume reports failing bricks
and will report a "Critical" problem when a volume becomes inaccessible.

**Target Configurations:** External, Hosted, Managed

#### Node Health

The Gluster operator will monitor the health of all nodes in an automated
Gluster cluster. It will report a "Critical" problem when a node becomes
inaccessible.

**Target Configurations:** External, Hosted, Managed

### Cluster Management

In response to the monitoring events above, the Gluster operator will take any
number of corrective management actions.

#### Storage Scaling

In the event that the overall cluster reports a critical capacity level, the
operator will deploy a set number of additional storage nodes with new storage
devices attached. The number of additional nodes to be deployed will be
configurable.

**Target Configurations:** Managed

#### Cluster Scaling

In the event that the overall cluster reports a critical volume density level,
the operator will deploy a new cluster of Gluster nodes to receive volume
creation requests. The number of additional nodes to be deployed will be
configurable.

**Target Configurations:** Managed

### Disaster Recovery

In response to the health monitoring events above, the Gluster operator will
take any number of corrective actions to recover from a situation that could
result in potential data loss.

#### Device Replacement

If a node reports a failing device, the Gluster operator will try to provision a
new device and attach it to the affected node to replace the failing device. It
would then wait for any affected volumes to be reconciled before removing the
failing device from it's node.

**Target Configurations:** Managed

#### Node Replacement

If a node becomes inaccessible, the Gluster operator will try to deploy a new
Gluster node with new storage devices attached. It would then wait for any
affected volumes to be reconciled before removing the failing node from the
cluster.

**Target Configurations:** Managed
