# Containerized Heketi with an dedicated GlusterFS cluster (static and dynamic provisioning)

Using GlusterFS and Heketi is a great way to perform static and dynamic provisioning 
in a Kubernetes based cluster for persistent volume shared filesystems.  Typically this is accomplished by running both
Heketi and GlusterFS as containerized components of the cluster (gk-deploy), but what about only running Heketi as a container 
and communicating with a dedicated GlusterFS cluster (non-containerized)?

This example will walk through a simple version of this setup to take advantage of existing dedicated storage environments while
still providing the benefits of reliability and failover from a Kubernetes environment.

This example assumes some familiarity with Kubernetes and the [Kubernetes Persistent Storage](http://kubernetes.io/docs/user-guide/persistent-volumes/) model.

This example also assumes you have access to an existing GlusterFS cluster that has raw devices available for consumption and management by Heketi Server.  If 
you do not have this, you can create a 3 node (CentOS or fedora) cluster using your Virtual Machine solution of choice and make sure you create a few raw devices and give
plenty of space.  See below for a quick start guide or [installing GluserFS Guide](https://www.gluster.org/)


### Environment and prerequisites for this example.

- GlusterFS Cluster running CentOS 7 (2 nodes, each with at least 2 X 200GB raw devices)
   - gluster25.rhs (192.168.1.205)
   - gluster26.rhs (192.168.1.206)

- Kubernetes Node running CentOS 7 (1.5 or later, this example will use the latest source from HEAD for 1.7 version)
   - k8dev3.rhs (192.168.1.209)
   - run a single node cluster using ./hack/local-up-cluster.sh

***NOTE:*** When running local-up-cluster.sh to build a single node Kubernets cluster I typically run export HOSTNAME_OVERRIDE=yourhostname

### Verify functioning and accessible dedicated GlusterFS environment

Below are some basic commands to help validate that your GlusterFS cluster is working properly.
Also, for this example, an existing volume was created to store the Heketi db file, to simulate a dedicated environment
with existing volumes.

#### Installing and configuring GlusterFS Nodes (If needed)

Install 2 nodes to run as the GlusterFS storage cluster and simulate an existing legacy environment. 
This example uses 2 CentOS 7 systems all running latest GlusterFS. More advanced and additional information can be found on the official [GlusterFS Site](https://www.gluster.org/)

***NOTE:*** 2 node clusters are not officially recommended as it causes some known replication issues (split brain), and if possible a 3+ node cluster should be used if possible.

#### View basic node and device information.

Execute `lsblk` command to show our raw devices (which will be used later in this example to load into Heketi).

```
	# lsblk
	NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
	sda           8:0    0   20G  0 disk 
	├─sda1        8:1    0    1G  0 part /boot
	└─sda2        8:2    0   19G  0 part 
	  ├─cl-root 253:0    0   17G  0 lvm  /
	  └─cl-swap 253:1    0    2G  0 lvm  [SWAP]
	sdb           8:16   0  200G  0 disk  <1>
	sdc           8:32   0  200G  0 disk  <2>
	sr0          11:0    1 1024M  0 rom  
```
<1> 200GB raw device that we will let Heketi manage

<2> 200GB raw device that we will let Heketi manage


#### Confirm proper access and communication between GlusterFS nodes.

- Update `/etc/hosts` with ip and hostname (i.e.  192.168.1.205 gluster25.rhs)
- Set up password-less SSH communication between all nodes

```
	# ssh-keygen  (take defaults)
	# ssh-copy-id -i /root/.ssh/id_rsa.pub root@gluster25.rhs
```
***NOTE:*** Repeat this from each node as necessary that you might want to ssh


#### Enable firewall rules.

Add Some Firewall Rules On All Nodes (if you have not disabled firewalld)

```
	# firewall-cmd --zone=public --add-service=glusterfs --permanent
	# firewall-cmd --reload
```

#### Check peer status and volume info for GlusterFS cluster.

```
	# gluster peer status
	# gluster volume list
```


### Prepare the Kubernetes Master and All Nodes
This directory structure will be used to store the SSH keys for heketi as well
as the configuration files that are needed.

````
	# mkdir -p /usr/share/heketi/keys
````

#### Validate communication and Gluster prerequisites on the Kubernetes node(s).

- Make sure glusterfs-client is installed

```
	# yum install epel-release -y
	# yum install glusterfs-client -y
	# modprobe fuse
```

- As with the other CentOS VMs that have been created, make sure the Kubernetes cluster has proper firewall access and can communicate with the heketi server and glusterfs servers.

```
	Update /etc/hosts...

	Add some firewall rules...
	# firewall-cmd --permanent --zone=public --add-port=8080/tcp
	# firewall-cmd --permanent --zone=public --add-port=8081/tcp
	# firewall-cmd --reload

	Add SELinux booleans for fuse...
	# setsebool -P virt_use_fusefs 1
	# setsebool -P virt_sandbox_use_fusefs 1
```



#### Install the Heketi-Client.
On the master node install the Heketi-Client.
Download the [latest Heketi release](https://github.com/heketi/heketi/releases) and untar it into the /etc/heketi directory.

```
	Install
	# wget https://github.com/heketi/heketi/releases/download/v4.0.0/heketi-client-v4.0.0.linux.amd64.tar.gz
	# mkdir -p /etc/heketi && tar xzvf heketi-client-v4.0.0.linux.amd64.tar.gz -C /etc/heketi

	Export PATH
	# export PATH=$PATH:/etc/heketi/heketi-client/bin
	# heketi-cli --version
	heketi-cli v4.0.0
```

***NOTE:*** The client can be installed on any node/system in your network that has access to the Kubernetes cluster and GlusterFS cluster.

#### Create Heketi private keys on master node.

A private key is needed for Heketi to communicate with the Gluster nodes, to accomplish this
we will create the ssh keys from the master (or one of the nodes in the cluster), 
and generate a Kubernetes secret that can be used for cluster communication to GlusterFS storage pool.

From the master node.

```
	If not already created, create the keys directory:
        # mkdir -p /usr/share/heketi/keys

        On the master node:	
	# cd /usr/share/heketi/keys  <1>
 	# ssh-keygen -f /usr/share/heketi/keys/heketi_key -t rsa -N ''  <2>
 	# ssh-copy-id -i /usr/share/heketi/keys/heketi_key.pub root@gluster25.rhs <3>
	# ssh-copy-id -i /usr/share/heketi/keys/heketi_key.pub root@gluster26.rhs <3>
	# chmod 770 heketi* <4>
```
<1> Change directory to the dir that was created earlier

<2> Generate the ssh key

<3> copy each ssh key to the dedicated gluster cluster nodes

<4> Change the permissions on the keys


#### Create the Heketi secret in Kubernetes

```
	# kubectl create secret generic ssh-key-secret --from-file=/usr/share/heketi/keys
	secret "ssh-key-secret" created
``` 


#### Obtain and edit the Heketi configuration file to setup the SSH executor.

The heketi.json file is used to configure Heketi on initial container start up. There are multiple
ways to create and have Heketi properly access and load this file, for this
example we are simply creating a configmap from the file that can be easily passed
around the cluster.  Alternatively you could simply copy the heketi.json file
to each node and put in /usr/share/heketi and create a hostPath volume or
even store on another share point (GlusterFS volume or NFS, etc...). A sample
heketi.json file is included with this repo or you can obtain the latest from
the Heketi repo. 


Below is an excerpt from the heketi.json file highlighting the sections
that potentially could/would need to be changed for your environment.

```
	{
  	"_port_comment": "Heketi Server Port Number",
  	"port": "8081",  <1>
	...
        ...
	"executor": "ssh",  <2>

	"_sshexec_comment": "SSH username and private key file information",
	"sshexec": {
  	  "keyfile": "/usr/share/keys/heketi_key",  <3>
  	  "user": "root",  <4>
  	  "port": "22",  <5>
  	  "fstab": "/etc/fstab"  <6>
	},
        ...
        
```
<1> Default port is 8080, you can configure a different port like 8081, especially if 8080 is already in use.

<2> Change "executor": from mock to ssh

<3> Add in the public key directory specified in previous step from the perspective of the pods directory 
defined in the heketi-deployment.yaml (where the secret volume will be mounted in the pod) 

<4> Update SSH user (should have sudo/root type access)

<5> Set the port to 22 - remove all other text

<6> Set the fstab to default (etc/fstab) - remove all other text

#### Create the configmap from the heketi.json file

```
	# kubectl create configmap heketi-config --from-file=/usr/share/heketi/heketi.json
	configmap "heketi-config" created
```


#### Create the dedicated GlusterFS cluster endpoints and service.

The endpoints and service are used to access the GlusterFS cluster to establish mounts.
These are used for our ReplicationController/Container in future steps and also can be reused
for any other pods that need access to GlusterFS cluster.
Run the following yaml examples.

glusterfs-endpoints.yaml
```
apiVersion: v1
kind: Endpoints
metadata:
 name: glusterfs-cluster
subsets:
 - addresses:
   - ip: 192.168.1.205
   ports:
   - port: 1
     protocol: TCP
 - addresses:
   - ip: 192.168.1.206
   ports:
   - port: 1
     protocol: TCP
```

gluster-service.yaml
```
kind: Service
apiVersion: v1
metadata:
  name: glusterfs-cluster
spec:
  ports:
  - port: 1
```

#### Create the Heketi deployment
A Kubernetes deployment will create a deployment, ReplicaSet (next generation Replication Controller) and the container pods.
A sample heketi-deployment.yaml is included below.

```
	# kubectl create -f heketi-deployment.yaml
	deployment "heketi-deployment" created
```

heketi-deployment.yaml
```
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: heketi-deployment
  labels:
    app: heketi
  annotations:
    description: Defines how to deploy Heketi
spec:
  replicas: 1
  template:
    metadata:
      name: heketi
      labels:
        app: heketi
    spec:
      hostNetwork: true
      containers:
      - name: heketi
        image: heketi/heketi:dev
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: keys
          mountPath: /usr/share/keys  <1>
        - name: config
          mountPath: /etc/heketi  <2>
        - name: db
          mountPath: /var/lib/heketi  <3>
      volumes:
        - name: keys
          secret:
            secretName: ssh-key-secret  <1>
        - name: config
          configMap:
            name: heketi-config  <2>
        - name: db
          glusterfs:
            endpoints: glusterfs-cluster
            path: MyHeketi  <3>
```

<1>  The ssh secret key mount and volume

<2>  The Heketi config configmap mount and volume.

<3>  Set up a Heketi db volume and path to store the heketi.db.  Notice we are using a volume on our actual GlusterFS cluster to store this heketi.db (volume should be greater than 40Gb).



***NOTE:*** For this example we have a chosen a Deployment, but a DaemonSet or even a simple ReplicationController would also acceptable.

#### Create the Heketi Service.
A service will expose the Heketi port.
From the master node run the following commands:

```
	Get the ReplicaSet name to pass into our `kubectl expose`
	# kubectl get rs
	NAME                	      DESIRED   CURRENT   READY     AGE
	heketi-deployment-4226138653   1         1         1         34m

	Create the ReplicaSet service
	# kubectl expose rs heketi-deployment-4226138653 --port=8081 --target-port=8081 --name=heketi-service
	service "heketi-service" exposed

	This would also work, but currently there is a bug in latest code base (will replace when fixed)
	# kubectl expose deployment heketi-deployment --port=8081 --target-port=8081 --type=LoadBalancer --name=heketi-service
	error: no kind "Deployment" is registered for version "apps/v1beta1"
```


#### Validate the Heketi pod is running.

```
	# kubectl get deployment
	NAME                KIND
	heketi-deployment   Deployment.v1beta1.apps


	# kubectl get rs
	NAME                           DESIRED   CURRENT   READY     AGE
	heketi-deployment-4226138653   1         1         1         42m


	# kubectl get pod -o wide
	NAME                                 READY     STATUS    RESTARTS   AGE       IP              NODE
	heketi-deployment-4226138653-2gcc3   1/1       Running   0          43m       192.168.1.209   k8dev3.rhs


	# kubectl logs heketi-deployment-4226138653-2gcc3
	Heketi v4.0.0-46-g8e58761
	[heketi] INFO 2017/03/21 16:18:54 Loaded ssh executor
	[heketi] INFO 2017/03/21 16:18:54 Loaded simple allocator
	[heketi] INFO 2017/03/21 16:18:54 GlusterFS Application Loaded
	Listening on port 8081
```

***NOTE:*** Because we used HOSTNAME_OVERRIDE environment variable to start local-up-cluster.sh and set the hostNetwork: true in our container
the container picks up the actual ipaddr of the node it is running on.

#### Test connection to Heketi.

```
	# curl http://k8dev3.rhs:8081/hello
	Hello from Heketi
```

#### Set an environment variable for the Heketi Server.
In a previous step we have installed the Heketi-Client on our 
master node.


```
	# export HEKETI_CLI_SERVER=http://k8dev3.rhs:8081
```

### Using Heketi with Gluster

A topology file is used to tell Heketi about the GlusterFS storage environment and what devices will be loaded and managed.

***NOTE:*** Heketi is currently limited to managing raw devices only, if a device is already a Gluster volume it
will be skipped and ignored.



#### Create and load the topology file.

There is a sample file located in /etc/heketi/heketi-client/share/heketi/topology-sample.json depending on where you unpacked the client from previous step.
The lsblk command run from the GlusterFS nodes can help determine what devices are available, for this example I will only load the /dev/sdc device into the
topology.

```
	# lsblk
	NAME                                                                              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
	sda                                                                                 8:0    0  100G  0 disk 
	└─vg_brick1-lv_brick1                                                             253:2    0   20G  0 lvm  /mnt/registry
	sdb                                                                                 8:16   0  100G  0 disk 
	└─vg_brick2-lv_brick2                                                             253:23   0   80G  0 lvm  /mnt/heketimgmt
	sdc                                                                                 8:32   0  100G  0 disk <1>
	sdd                                                                                 8:48   0  100G  0 disk <2>
	sde                                                                                 8:64   0  100G  0 disk <3>
```
<1> Available device as /dev/sdc

<2> Available device as /dev/sdd

<3> Available device as /dev/sde


Example topology.json file
```
{
  "clusters": [
    {
      "nodes": [
        {
          "node": {
            "hostnames": {
              "manage": [
                "gluster25.rhs"  <1>
              ],
              "storage": [
                "192.168.1.205"  <2>
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdc"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "gluster26.rhs"
              ],
              "storage": [
                "192.168.1.206"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdc"
          ]
        }
      ]
    }
  ]
}
```
<1> The manage element should be the fully qualified hostname (not the ip address).

<2> The storage element should be the ip address of the storage node (not the fqdn).


***NOTE:*** The `manage` element in the above json file should be the actual hostname of the GlusterFS node, 
and the `storage` element should be the actual ip address of the storage node as it is in the glusterfs-endpoints. 

#### Using heketi-cli, run the following command to load the topology of your environment.

```
	# heketi-cli topology load --json=topology.json
	Found node gluster25.rhs on cluster bfd8d40abd5092c4d7c072cf80d0444c
		Adding device /dev/sdc ... OK
	Creating node gluster26.rhs ... ID: 35997ef9bd1ec225713d0eaff5abe9d5
		Adding device /dev/sdc ... OK
```



#### Create a Gluster volume to verify Heketi.

```
	# heketi-cli volume create --size=20 --replica=2
	
	Name: vol_fe4a7ebca82b989cd7d101945852462b
	Size: 10
	Volume Id: fe4a7ebca82b989cd7d101945852462b
	Cluster Id: bfd8d40abd5092c4d7c072cf80d0444c
	Mount: 192.168.1.205:vol_fe4a7ebca82b989cd7d101945852462b
	Mount Options: backup-volfile-servers=192.168.1.206
	Durability Type: replicate
	Distributed+Replica: 2
```

***NOTE:*** --replica=2 only needed if you have a 2 node cluster, not a standard 3+ node cluster

#### View the volume information from one of the the Gluster nodes:

```
	# gluster volume list
	MyVolume
	registry
	vol_1b2b344fa375ea17a403e35c3f91dc89
	vol_c8204282e60d55ce9308404e667425c5
	vol_fe4a7ebca82b989cd7d101945852462b <1>



	# gluster volume info vol_fe4a7ebca82b989cd7d101945852462b
	Volume Name: vol_fe4a7ebca82b989cd7d101945852462b <1>
	Type: Distributed-Replicate
	Volume ID: 75be7940-9b09-4e7f-bfb0-a7eb24b411e3
	Status: Started
        ...
	...
```
<1> Volume created by heketi-cli.



### Dynamically Provision a Volume from Kubernetes.

Using the Kubernetes cluster (for this example a single node cluster using ./hack/local-up-cluster.sh). As stated, this part of
the example assumes some familiarity with Kubernetes (installing, running, etc...).



#### Create a Storage Class.

Below definition is based on Kuberenetes 1.6, this version of Storage Class is the minimum needed for this
example to work.  There are other parameters for more advanced use cases and they can be seen in the latest Kubernetes
documentation.


```
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: gluster-dyn
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://k8dev3.rhs:8081"  <1>
  restauthenabled: "false"  <2>
  volumetype: "replicate:2" <3>
```
<1> The resturl pointing to the Heketi Server from HEKETI_CLI_SERVER env variable.

<2> Since we did not turn on authentication, setting this to false.

<3> Typically this parameter is not needed, but since we have a 2 node storage pool, we need to specify that we are doing a 2 node replica set.

***NOTE:*** Recommended and default replica setting is 3, if you have a 3 node storage pool already, no need to pass in the volumetype parameter.


#### From the Kubernetes master node, using kubectl, create the storage class.

```
	# kubectl create -f glusterfs-storageclass1.yaml
	storageclass "gluster-dyn" created
```

#### Now create a pvc, requesting the storage class, below is a sample definition.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: gluster-dyn-pvc
 annotations:
   volume.beta.kubernetes.io/storage-class: gluster-dyn
spec:
 accessModes:
  - ReadWriteMany
 resources:
   requests:
 	storage: 20Gi
```

#### From the Kubernetes master node, create the pvc.

```
	# kubectl create -f glusterfs-pvc-storageclass.yaml
	persistentvolumeclaim "gluster-dyn-pvc" created
```

#### View the pvc to see that the volume was dynamically created and bound to the pvc.

```
	# kubectl get pv
	NAME                                       CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                     STORAGECLASS   REASON    AGE
	pvc-cf518abc-0e7f-11e7-b2e0-080027d93841   20Gi       RWX           Delete          Bound     default/gluster-dyn-pvc                            2s

	# kubectl get pvc
	NAME              STATUS    VOLUME                                     CAPACITY   ACCESSMODES   STORAGECLASS   AGE
	gluster-dyn-pvc   Bound     pvc-cf518abc-0e7f-11e7-b2e0-080027d93841   20Gi       RWX           gluster-dyn    21s
```

#### Verify and view the new volume on one of the Gluster Nodes.

```
	# gluster volume list
	MyVolume
	registry
	vol_1b2b344fa375ea17a403e35c3f91dc89
	vol_c8204282e60d55ce9308404e667425c5
	vol_fe4a7ebca82b989cd7d101945852462b <1>
	vol_fe4a7ebca82b989cd7d101945852462b <2>
```
<1> Volume created by heketi-cli in previous manual step.

<2> New dynamically created volume triggered by Kubernetes and the Storage Class.




### Create a NGINX pod that uses the PVC

At this point we have a dynamically created GlusterFS volume, bound to a PersistentVolumeClaim, we can now utilize this claim
in a pod.  We will create a simple NGINX pod.

```
apiVersion: v1
kind: Pod
metadata:
  name: gluster-pod1
  labels:
    name: gluster-pod1
spec:
  containers:
  - name: gluster-pod1
    image: gcr.io/google_containers/nginx-slim:0.8
    ports:
    - name: web
      containerPort: 80
    securityContext:
      privileged: true
    volumeMounts:
    - name: gluster-vol1
      mountPath: /usr/share/nginx/html
  volumes:
  - name: gluster-vol1
    persistentVolumeClaim:
      claimName: gluster-dyn-pvc <1>
```
<1> The name of the PVC created in the previous step



#### Create the Pod YAML file.  Save it.  Then submit it to Kubernetes.

```
kubectl create -f nginx-pod.yaml
pod "gluster-pod1" created
```

#### View the Pod (Give it a few minutes, it might need to download the image if it doesn't already exist):

```
kubectl get pods -o wide
NAME                               READY     STATUS    RESTARTS   AGE       IP               NODE
gluster-pod1                       1/1       Running   0          9m        10.38.0.0        node1

```

#### Now we will exec into the container and create an index.html file.

```
kubectl exec -ti gluster-pod1 /bin/sh
$ cd /usr/share/nginx/html
$ echo 'Hello World from GlusterFS!!!' > index.html
$ ls
index.html
$ exit
```

#### Now we can curl the URL of our pod:

```
curl http://10.38.0.0
Hello World from GlusterFS!!!
```

