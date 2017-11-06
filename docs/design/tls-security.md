# Enabling security in Gluster/Kubernetes
This design proposal describes a plan to enable Gluster’s TLS security for both
the management as well as the data path when Gluster is used as persistent
storage in Kubernetes.

## Motivation
Currently, the default installation of Gluster for storage in Kubernetes (via
gluster-kubernetes) does not enable Gluster’s TLS security for either the
management nor for the data path operations. Without TLS security enabled,
Gluster will serve volumes and requests to any client that has permission
according to Gluster’s `auth.allow` and `auth.deny` volume options. This allows
clients to be restricted based on IP address, and UID/GID or ACLs are the
mechanisms for controlling authorization of users on those clients.

In a containerized environment, the network traffic sent by a container (pod)
appears to originate from the hosting node, making it indistinguishable from
traffic sent by the node’s infrastructure components. The result is that with
just IP restriction, it is not possible to permit a node to access/mount a
Gluster volume (to provide storage to a container), while preventing a
container from directly accessing that same Gluster server in a malicious way.

With TLS security enabled, clients must present a valid certificate to the
Gluster server in order to mount and access volumes. The certificate data is
stored at a location on the client nodes that does not (by default) get mapped
into the container’s file system tree, preventing processes within a container
from being able to directly access the Gluster server. Intended access (as
persistent volume storage) is still permitted because the relevant process
handling the mount and data access (e.g., fuse) is run directly on the host. In
the case of containerized mounts, it would be possible to bind mount the
certificate data into the container holding the mount utilities.

## Approach
In order to enable TLS, a number of conditions must be met:
* TLS keys and certificates must be generated and distributed to each client
  and server
* The file: `/var/lib/glusterd/secure-access` must be present on each client
  and server machine.

Additionally, to enable TLS for the data path, `client.ssl` and `server.ssl`
options must be enabled for each volume.

When using TLS keys in Gluster, the TLS keys for each machine can be
self-signed keys, or a common certificate authority (CA) can be used. In the
case of self-signed keys, each client’s certificate would need to be
distributed to each server, and each server’s certificate would need to be
distributed to both servers and clients. For large infrastructures, this is
impractical.

For keys signed by a common CA, only the CA certificate needs to be distributed
to all machines, meaning no changes would be required if additional machines
(clients or servers) are added to the infrastructure, other than generating a
signed certificate for that new machine.

### Client (node) configuration
For a Kubernetes node to be able to access a Gluster server (with TLS), it
needs to have a key and certificate file generated
(`/etc/ssl/glusterfs.[key|pem]`), and it needs to have a copy of the common
CA’s certificate (`/etc/ssl/glusterfs.ca`).

The proposal is to have the common CA (both key and pem) stored in a kubernetes
secret in a namespace that is specific to Gluster (e.g., `glusterfs`). This
would restrict access in a way similar to how the heketi key is managed today.
This common CA key could also be signed by the cluster's top-level CA. This may
provide future advantages for cross cluster operations such as georeplication.

To distribute the TLS keys to each node, a DaemonSet would be created to run on
each node. This DS would have access to the CA secret as well as the path on
the host corresponding to `/etc/ssl`. Upon startup, it would use the CA key to
generate and sign a key pair for the node and place them, along with a copy of
the CA certificate, in `/etc/ssl/glusterfs.*`. It would then create the
`/var/lib/glusterd/secure-access` file, which would also be exposed to the DS
via a host path mapping. Note, that the secure-access file is specifically
created as the final step to ensure proper sequencing with a containerized
Gluster server (see below).

In the event that the DS starts and sees an existing set of key files, it
should check whether the `glusterfs.ca` matches the certificate in the secret
and whether the `glusterfs.key` and `glusterfs.pem` files are properly signed
with that CA. If any of those checks fail, the CA certificate should be
re-copied and the node’s key/pem regenerated. These steps would permit keys to
be updated and/or fixed by optionally updating the secret and respawning the
DS.

### Containerized Gluster configuration
The DaemonSet described above would also run on nodes that host the Gluster
server containers. The gluster containers already mount the `/etc/ssl`
directory from the host, meaning that once the DS creates them, they would be
visible to the containerized server. Likewise, `/var/lib/glusterd` is also
mapped from the host, giving access to the secure-access marker file.

Care must be taken to ensure sequencing between the security DS and the Gluster
server startup. The Gluster server must only be started once the keys and the
secure-access file are in place. To accomplish this, we propose the addition of
an optional environment variable, `ENABLE_TLS`, to the Gluster server pod
template. If this variable is set to `1`, glusterd should not be started until
the secure-access file is present. If the variable is `0` or unset, glusterd
should be started immediately as is the behavior today.

### External Gluster configuration
For Gluster servers that run outside of the containerized environment, the
administrator is responsible for generating and installing the key,
pem, ca, and secure-access files. This is no different than in a traditional
deployment of Gluster.

### Data path security
The DaemonSet is sufficient to enable management security for Gluster, but data
path security must be enabled on a per-volume basis by setting options on each
volume. In the case of dynamic provisioning, it would be the responsibility of
heketi to ensure that the `client.ssl` and `server.ssl` options are enabled
when a volume is created. Version XXX of heketi added support for generic
volume options passed via the StorageClass that is used for provisioning. As a
result, no modifications are required to heketi, only a small change to the
StorageClass that is used.

### Bootstrapping the CA secret
The above approach assumes the presence of a secret holding the CA key and
certificate. As a part of deploying Gluster, this secret must be created (i.e.,
the keys must be generated). This could be handled by a Job that is spawned at
the time Gluster and heketi are deployed. By containerizing the secret
creation, the key generation tools (openssl) are guaranteed to exist and be of
a suitable version. Deployment of the DS and Gluster pods would necessarily
wait for the completion of this secret creation Job.

## Alternatives
This section lists other approaches that were considered but not chosen.

### Direct install of keys on nodes
Instead of using a DS on each node, it is possible to install the key, pem, ca,
and secure-access files directly on the nodes, either manually or via
automation such as Ansible. While this would work, it requires access to the
individual hosts separate from that provided by the Kubernetes infrastructure.
Additionally, it requires the CA key and pem to be managed outside of the
infrastructure as well.

### Self-signed keys
Using self-signed keys requires the certificates from all nodes to be
concatenated and stored in the glusterfs.ca file. This means that when adding a
node to the infrastructure, the .ca file on each node would need to be updated,
making it difficult to ensure consistent, atomic updates that are
non-disruptive to the cluster’s storage.
