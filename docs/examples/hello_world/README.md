# Hello World application using GlusterFS Dynamic Provisioning

At this point, we have a working Kubernetes cluster deployed, and a working Heketi Server.
Next we will create a simple NGINX HelloWorld application utilizing Kubernetes Dynamic Provisioning and 
Heketi.

This example assumes some familiarity with Kubernetes and the [Kubernetes Persistent Storage](http://kubernetes.io/docs/user-guide/persistent-volumes/) model.


### Verify our environment and gather some information to be used in later steps.

Identify the Heketi REST URL and Server IP Address:

```
$ echo $HEKETI_CLI_SERVER
http://10.42.0.0:8080
```

By default, `user_authorization` is disabled. If it were enabled, you might
also need to find the rest user and rest user secret key (not applicable for
this example as any values will work). It is also possible to configure a
`secret` and pass the credentials to the Gluster dynamic provisioner via
StorageClass parameters.

#### Dynamic provisioner in Kubernetes 1.4 ####

***NOTE***: Endpoints define the GlusterFS cluster, for version 1.4.X this is
a required parameter for the StorageClass. For versions later than 1.4.X skip
this step.

Identify the Gluster Storage Endpoint to be passed in as a parameter to
the StorageClass (heketi-storage-endpoints):

```
kubectl get endpoints
NAME                       ENDPOINTS                                            AGE
heketi                     10.42.0.0:8080                                       22h
heketi-storage-endpoints   192.168.10.100:1,192.168.10.101:1,192.168.10.102:1   22h
kubernetes                 192.168.10.90:6443                                   23h
```

#### Dynamic provisioner in Kubernetes >= 1.5 ####

Starting with Kubernetes 1.5 a manual Endpoint is no longer necessary for the
GlusterFS dynamic provisioner. In Kubernetes 1.6 and later manually specifying
an endpoint will cause the provisioning to fail. When the dynamic provisioner
creates a volume it will also automatically create the Endpoint.

There are other StorageClass parameters (e.g. cluster, GID) which were added
to the Gluster dynamic provisioner in Kubernetes. Please refer to
[GlusterFS Dynamic Provisioning](https://github.com/kubernetes/kubernetes/blob/master/examples/experimental/persistent-volume-provisioning/README.md)
for more details on these parameters.

### Create a _StorageClass_ for our GlusterFS Dynamic Provisioner

[Kuberentes Storage Classes](http://kubernetes.io/docs/user-guide/persistent-volumes/#storageclasses) are used to
manage and enable Persistent Storage in Kubernetes.  Below is an example of a _Storage Class_ that will request
5GB of on-demand storage to be used with our _HelloWorld_ application.


##### For Kubernetes 1.4:
```
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-heketi  <1>
provisioner: kubernetes.io/glusterfs  <2>
parameters:
  endpoint: "heketi-storage-endpoints"  <3>
  resturl: "http://10.42.0.0:8080"  <4>
  restuser: "joe"  <5>
  restuserkey: "My Secret Life"  <6>
```

##### For Kubernetes 1.5 and later:
```
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: gluster-heketi  <1>
provisioner: kubernetes.io/glusterfs  <2>
parameters:
  resturl: "http://10.42.0.0:8080"  <4>
  restuser: "joe"  <5>
  restuserkey: "My Secret Life"  <6>
```
<1> Name of the Storage Class

<2> Provisioner

<3> GlusterFS defined EndPoint taken from Step 1 above (kubectl get endpoints). For Kubernetes >= 1.6, this parameter should be removed as Kubernetes will reject this YAML definition.

<4> Heketi REST Url, taken from Step 1 above (echo $HEKETI_CLI_SERVER), may also be set to the Kubernetes service DNS name for the Heketi service.

<5> Restuser, can be anything since authorization is turned off

<6> Restuserkey, like Restuser, can be anything

Create the Storage Class YAML file.  Save it.  Then submit it to Kubernetes

```
kubectl create -f gluster-storage-class.yaml
storageclass "gluster-heketi" created
```

View the Storage Class:

```
kubectl get storageclass
NAME              TYPE
gluster-heketi    kubernetes.io/glusterfs
```


### Create a PersistentVolumeClaim (PVC) to request storage for our HelloWorld application.

Next, we will create a PVC that will request 5GB of storage, at which time, the Kubernetes Dynamic Provisioning Framework and Heketi
will automatically provision a new GlusterFS volume and generate the Kubernetes PersistentVolume (PV) object.

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: gluster1
 annotations:
   volume.beta.kubernetes.io/storage-class: gluster-heketi  <1>
spec:
 accessModes:
  - ReadWriteOnce
 resources:
   requests:
     storage: 5Gi <2>
```
<1> The Kubernetes Storage Class annotation and the name of the Storage Class

<2> The amount of storage requested


Create the PVC YAML file.  Save it.  Then submit it to Kubernetes

```
kubectl create -f gluster-pvc.yaml
persistentvolumeclaim "gluster1" created
```

View the PVC:

```
kubectl get pvc
NAME       STATUS    VOLUME                                     CAPACITY   ACCESSMODES   AGE
gluster1   Bound     pvc-7d37c7bd-bb5b-11e6-b81e-525400d87180   5Gi        RWO           14h

```

Notice, that the PVC is bound to a dynamically created volume.  We can also view
the Volume (PV):

```
kubectl get pv
NAME                                       CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM              REASON    AGE
pvc-7d37c7bd-bb5b-11e6-b81e-525400d87180   5Gi        RWO           Delete          Bound     default/gluster1             14h

```

### Create a NGINX pod that uses the PVC

At this point we have a dynamically created GlusterFS volume, bound to a PersistentVolumeClaim, we can now utilize this claim
in a pod.  We will create a simple NGINX pod.

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod1
  labels:
    name: nginx-pod1
spec:
  containers:
  - name: nginx-pod1
    image: gcr.io/google_containers/nginx-slim:0.8
    ports:
    - name: web
      containerPort: 80
    volumeMounts:
    - name: gluster-vol1
      mountPath: /usr/share/nginx/html
  volumes:
  - name: gluster-vol1
    persistentVolumeClaim:
      claimName: gluster1 <1>
```
<1> The name of the PVC created in step 3



Create the Pod YAML file.  Save it.  Then submit it to Kubernetes

```
kubectl create -f nginx-pod.yaml
pod "nginx-pod1" created
```

View the Pod (Give it a few minutes, it might need to download the image if it doesn't already exist):

```
kubectl get pods -o wide
NAME                               READY     STATUS    RESTARTS   AGE       IP               NODE
nginx-pod1                         1/1       Running   0          9m        10.38.0.0        node1
glusterfs-node0-2509304327-vpce1   1/1       Running   0          1d        192.168.10.100   node0
glusterfs-node1-3290690057-hhq92   1/1       Running   0          1d        192.168.10.101   node1
glusterfs-node2-4072075787-okzjv   1/1       Running   0          1d        192.168.10.102   node2
heketi-3017632314-yyngh            1/1       Running   0          1d        10.42.0.0        node0

```

Now we will exec into the container and create an index.html file

```
kubectl exec -ti nginx-pod1 /bin/sh
$ cd /usr/share/nginx/html
$ echo 'Hello World from GlusterFS!!!' > index.html
$ ls
index.html
$ exit
```

Now we can curl the URL of our pod:

```
curl http://10.38.0.0
Hello World from GlusterFS!!!
```

Lastly, let's check our gluster pod, to see the index.html file we wrote.  Choose any of the gluster pods

```
kubectl exec -ti glusterfs-node1-3290690057-hhq92 /bin/sh
$ mount | grep heketi
/dev/mapper/VolGroup00-LogVol00 on /var/lib/heketi type xfs (rw,relatime,seclabel,attr2,inode64,noquota)
/dev/mapper/vg_f92e09091f6b20ab12b02a2513e4ed90-brick_1e730a5462c352835055018e1874e578 on /var/lib/heketi/mounts/vg_f92e09091f6b20ab12b02a2513e4ed90/brick_1e730a5462c352835055018e1874e578 type xfs (rw,noatime,seclabel,nouuid,attr2,inode64,logbsize=256k,sunit=512,swidth=512,noquota)
/dev/mapper/vg_f92e09091f6b20ab12b02a2513e4ed90-brick_d8c06e606ff4cc29ccb9d018c73ee292 on /var/lib/heketi/mounts/vg_f92e09091f6b20ab12b02a2513e4ed90/brick_d8c06e606ff4cc29ccb9d018c73ee292 type xfs (rw,noatime,seclabel,nouuid,attr2,inode64,logbsize=256k,sunit=512,swidth=512,noquota)

$ cd /var/lib/heketi/mounts/vg_f92e09091f6b20ab12b02a2513e4ed90/brick_d8c06e606ff4cc29ccb9d018c73ee292/brick
$ ls
index.html
$ cat index.html 
Hello World from GlusterFS!!!
```









