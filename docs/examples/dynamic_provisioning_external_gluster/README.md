# Dynamic Provisioning with an Existing External GlusterFS Cluster (non-containerized)

Using GlusterFS and Heketi is a great way to perform dynamic provisioning 
in a Kubernetes based cluster for shared filesystems.  All that is needed is an existing Gluster cluster with available
storage and a Heketi Server running and managing the cluster devices.

This example will show how simple it is to install and configure a Heketi Server to work with
Kubernetes to perform dynamic provisioning. We will walk through setting up a GlusterFS cluster, installing
and configuring a Heketi Server and client and finally, using Kubernetes to dynamical provision storage.

This example assumes some familiarity with Kubernetes and the [Kubernetes Persistent Storage](http://kubernetes.io/docs/user-guide/persistent-volumes/) model.

This example also assumes you have access to an existing GlusterFS cluster that has raw devices available for consumption and management by Heketi Server.  If 
you do not have this, you can create a 3 node (CentOS or fedora) cluster using your Virtual Machine solution of choice and make sure you create a few raw devices and give
plenty of space.  See below for a quick start guide or [installing GluserFS Guide](https://www.gluster.org/)


### Environment and prerequisites for this example.

- GlusterFS Cluster running CentOS 7 (2 nodes, each with at least 2 X 200GB raw devices)
   - gluster25.rhs (192.168.1.205)
   - gluster26.rhs (192.168.1.206)

- Heketi Server/Client Node running CentOS 7 (Heketi can be installed on one of the Gluster Nodes if needed)
   - glusterclient3.rhs (192.168.1.203)

- Kubernetes Node running CentOS 7 (1.5 or later, this example will use the latest source from HEAD for 1.6 version)
   - k8dev3.rhs (192.168.1.209)


### Installing and configuring GlusterFS Nodes

Install 2 nodes to run as the GlusterFS storage cluster and simulate an existing legacy environment. 
This example uses 2 CentOS 7 systems all running latest GlusterFS. The following steps represent a quick guide on
how to install and configure these nodes to create a storage pool. More advanced and additional information can be found on the official [GlusterFS Site](https://www.gluster.org/)

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


#### Confirm proper access and communication between the storage nodes.

- Update `/etc/hosts` with ip and hostname (i.e.  192.168.1.205 gluster25.rhs)
- Set up password-less SSH communication between all nodes

```
	# ssh-keygen  (take defaults)
	# ssh-copy-id -i /root/.ssh/id_rsa.pub root@gluster25.rhs
```
***NOTE:*** Repeat this from each node as necessary


#### Download and install GlusterFS.


```
	# yum install wget telnet -y
	# yum install centos-release-gluster -y
	# yum install epel-release -y
	# yum install glusterfs-server -y
```

#### Start glusterd.

```
	# systemctl start glusterd
	# systemctl enable glusterd
```

#### Enable firewall rules.

Add Some Firewall Rules On All Nodes (if you have not disabled firewalld)

```
	# firewall-cmd --zone=public --add-service=glusterfs --permanent
	# firewall-cmd --reload
```


#### Setup the Storage Pool.

From one of the GlusterFS storage nodes, peer probe the other members of the pool

```
	# gluster peer probe gluster26.rhs
	peer probe: success. 

	# gluster peer status
	Number of Peers: 1

	Hostname: gluster26.rhs
	Uuid: 6d7a3149-e163-4de8-9e63-b00e9ceacc59
	State: Peer in Cluster (Connected)

```

From the other storage node (gluster26.rhs) - run the peer status

```
	# gluster peer status	
	Number of Peers: 1

	Hostname: gluster25.rhs
	Uuid: d4cbbdbf-5dca-46ba-a7d4-2cc5d8bcdb06
	State: Peer in Cluster (Connected)

```

***NOTE:*** Normally the above `peer probe` is not needed as Heketi will perform this function automatically, but since we are trying to simulate an existing GlusterFS cluster environment, the commands were left here as reference.


### Installing and configuring Heketi Server Node

Heketi is used to manage our gluster cluster storage (adding volumes, removing volumes, etc…). As already stated this example
uses a stand-alone virtual machine to run Heketi and the client, but this can be installed on one of the existing Gluster Storage Nodes.


#### Confirm and validate communication on the Heketi Server Node.

- Similar to the GlusterFS storage nodes, verify `/etc/hosts` and firewalls

```
	# firewall-cmd --permanent --zone=public --add-port=8080/tcp
	# firewall-cmd --reload
```

#### Install the Heketi Server.

Choose an existing Gluster Storage Node or another Node that can run the Heketi Server with access to the Gluster cluster.
For this example we are using a non-gluster stand-alone node. For more information see the [Heketi github site](https://github.com/heketi/heketi/wiki/Installation)

```
	# yum install wget telnet -y
	# yum install centos-release-gluster -y
	# yum install epel-release -y
	# yum install heketi -y

	# heketi version
	Heketi 3.1.0
	Please provide configuration file
```




#### Install the Heketi-Client.
Choose an existing Gluster Storage Node or another Node that can run the Heketi Server with access to the Gluster cluster.
Download the [latest Heketi release](https://github.com/heketi/heketi/releases) and untar it into the /etc/heketi directory.

```
	Install
	# wget https://github.com/heketi/heketi/releases/download/v3.1.0/heketi-client-v3.1.0-HEAD.linux.amd64.tar.gz
	# mkdir -p /etc/heketi && tar xzvf heketi-client-v3.1.0-HEAD.linux.amd64.tar.gz -C /etc/heketi

	Export PATH
	# export PATH=$PATH:/etc/heketi/heketi-client/bin
	# heketi-cli --version
	heketi-cli v3.1.0-HEAD

```


#### Create and install Heketi private keys on each cluster node.

From the Node that is running Heketi.

```
 	# ssh-keygen -f /etc/heketi/heketi_key -t rsa -N ''
 	# ssh-copy-id -i /etc/heketi/heketi_key.pub root@gluster25.rhs
	# ssh-copy-id -i /etc/heketi/heketi_key.pub root@gluster26.rhs
 	# chown heketi:heketi /etc/heketi/heketi_key*
```


#### Edit the /usr/share/heketi/heketi.json file to setup the SSH executor.

Below is an excerpt from the /usr/share/heketi/heketi.json file, the part to configure
is the executor and ssh section.

```
        ...
	"executor": "ssh",  <1>

	"_sshexec_comment": "SSH username and private key file information",
	"sshexec": {
  	  "keyfile": "/etc/heketi/heketi_key",  <2>
  	  "user": "root",  <3>
  	  "port": "22",  <4>
  	  "fstab": "/etc/fstab"  <5>
	},
```
<1> Change "executor": from mock to ssh

<2> Add in the public key directory specified in previous step

<3> Update SSH user (should have sudo/root type access)

<4> Set the port to 22 - remove all other text

<5> Set the fstab to default (etc/fstab) - remove all other text


#### Restart and enable Heketi.

```
	# systemctl restart heketi
	# systemctl enable heketi
	# systemctl status heketi

● heketi.service - Heketi Server
   Loaded: loaded (/usr/lib/systemd/system/heketi.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2017-01-25 12:32:10 EST; 11s ago
 Main PID: 2500 (heketi)
   CGroup: /system.slice/heketi.service
           └─2500 /usr/bin/heketi -config=/etc/heketi/heketi.json

Jan 25 12:32:10 glusterclient3.rhs systemd[1]: Started Heketi Server.
Jan 25 12:32:10 glusterclient3.rhs systemd[1]: Starting Heketi Server...
Jan 25 12:32:10 glusterclient3.rhs heketi[2500]: Heketi 2.0.6
Jan 25 12:32:11 glusterclient3.rhs heketi[2500]: [heketi] INFO 2017/01/25 12...r
Jan 25 12:32:11 glusterclient3.rhs heketi[2500]: [heketi] INFO 2017/01/25 12...r
Jan 25 12:32:11 glusterclient3.rhs heketi[2500]: [heketi] INFO 2017/01/25 12...d
Jan 25 12:32:11 glusterclient3.rhs heketi[2500]: Listening on port 8080

```

#### Test connection to Heketi.

```
	# curl http://glusterclient3.rhs:8080/hello
	Hello from Heketi
```

#### Set an environment variable for the Heketi Server.

```
	# export HEKETI_CLI_SERVER=http://glusterclient3.rhs:8080
```

### Using Heketi with Gluster

Topology is used to tell Heketi about the environment, what nodes and devices it will manage.

***NOTE:*** Heketi is currently limited to managing raw devices only, if a device is already a Gluster volume it
will be skipped and ignored.



#### Create and load the topology file.

There is a sample file located in /etc/heketi/heketi-client/share/heketi/topology-sample.json depending on where you unpacked the client from previous step.


```
{
  "clusters": [
    {
      "nodes": [
        {
          "node": {
            "hostnames": {
              "manage": [
                "gluster25.rhs"
              ],
              "storage": [
                "192.168.1.205"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdb",
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
            "/dev/sdb",
            "/dev/sdc"
          ]
        }
      ]
    }
  ]
}
```

#### Using heketi-cli, run the following command to load the topology of your environment.

```
	# heketi-cli topology load --json=topology.json

    	Found node gluster25.rhs on cluster bdf9d8ca3fa269ff89854faf58f34b9a
   		Adding device /dev/sdb ... OK
   	 	Adding device /dev/sdc ... OK
    	Creating node gluster26.rhs ... ID: 8e677d8bebe13a3f6846e78a67f07f30
   	 	Adding device /dev/sdb ... OK
   	 	Adding device /dev/sdc ... OK
	...
	...
```



#### Create a Gluster volume to verify Heketi.

```
	# heketi-cli volume create --size=20 --replica=2
```

***NOTE:*** --replica=2 only needed if you have a 2 node cluster, not a standard 3+ node cluster

#### View the volume information from one of the the Gluster nodes:

```
	# gluster volume list
	vol_c8204282e60d55ce9308404e667425c5 <1>


	# gluster volume info
	Volume Name: vol_c8204282e60d55ce9308404e667425c5 <1>
	Type: Distributed-Replicate
	Volume ID: 75be7940-9b09-4e7f-bfb0-a7eb24b411e3
	Status: Started
        ...
	...

```
<1> Volume created by heketi-cli.



### Dynamically Provision a Volume from Kubernetes

Using the Kubernetes cluster (for this example a single node cluster using ./hack/local-up-cluster.sh). As stated, this part of
the example assumes some familiarity with Kubernetes (installing, running, etc...).

#### Validate communication and Gluster prerequisites on the Kubernetes node(s).

- Make sure glusterfs-client is installed

```
	# yum install centos-release-gluster -y
	# yum install epel-release -y
	# yum install glusterfs-client -y
	# modprobe fuse
```

- As with the other CentOS VMs that have been created, make sure the Kubernetes cluster has proper firewall access and can communicate with the heketi server and glusterfs servers.

```
	Update /etc/hosts...

	Add some firewall rules...
	# firewall-cmd --zone=public --add-service=glusterfs --permanent
	# firewall-cmd --permanent --zone=public --add-port=8080/tcp
	# firewall-cmd --reload

	Add SELinux booleans for fuse...
	# setsebool -P virt_use_fusefs 1
	# setsebool -P virt_sandbox_use_fusefs 1

	Access Heketi Server...
	# curl http://glusterclient3.rhs:8080/hello
	Hello from Heketi

```




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
  resturl: "http://glusterclient3.rhs:8080"  <1>
  restauthenabled: "false"  <2>
  volumetype: "replicate:2" <3>
  
```
<1> The Heketi Server from HEKETI_CLI_SERVER env variable.

<2> Since we did not turn on authentication, setting this to false.

<3> Typically this parameter is not needed, but since we have a 2 node storage pool, we need to specify that

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
 	storage: 30Gi
```

#### From the Kubernetes master node, create the pvc.

```
	# kubectl create -f glusterfs-pvc-storageclass.yaml
	persistentvolumeclaim "gluster-dyn-pvc" created
```

#### View the pvc to see that the volume was dynamically created and bound to the pvc.

```
	# kubectl get pvc
	NAME          	STATUS	VOLUME                                 	CAPACITY   ACCESSMODES   STORAGECLASS   AGE
	gluster-dyn-pvc   Bound 	pvc-78852230-d8e2-11e6-a3fa-0800279cf26f   30Gi   	RWX       	gluster-dyn	42s
```

#### Verify and view the new volume on one of the Gluster Nodes.

```
	# gluster volume list
	vol_1b2b344fa375ea17a403e35c3f91dc89
	vol_c8204282e60d55ce9308404e667425c5

	# gluster volume info
 
	Volume Name: vol_c8204282e60d55ce9308404e667425c5 <1>
	Type: Distributed-Replicate
	Volume ID: 75be7940-9b09-4e7f-bfb0-a7eb24b411e3
	Status: Started
        ...
	Volume Name: vol_1b2b344fa375ea17a403e35c3f91dc89  <2>
	Type: Distributed-Replicate
	Volume ID: 7dc234d0-462f-4c6c-add3-fb9bc7e8da5e
	Status: Started
	Number of Bricks: 2 x 2 = 4
	...

```
<1> Volume created by heketi-cli.

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










