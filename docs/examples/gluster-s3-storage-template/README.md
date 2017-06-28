# Gluster S3 docker container using template


## Prerequisites

  OpenShift setup is up with master and nodes ready.

  cns-deploy tool is ran and heketi service is ready




## First create a storageclass

```
oc create -f ./gluster-s3-storageclass.yaml
```

Available at 
[gluster-s3-storageclass.yaml](./gluster-s3-storageclass.yaml)

## Start glusters3 service using template

```
oc new-app gluster-s3-template.yaml  --param=GLUSTER_VOLUMES=testvolume  --param=GLUSTER_USER=adminuser --param=GLUSTER_PASSWORD=itsmine --param=VOLUME_CAPACITY=2Gi
```

Note: adjust parameters according to your needs.

Available at:
[gluster-s3-template.yaml](./gluster-s3-template.yaml)

### For example:


```
[root@master template]# oc new-app glusters3template.json  --param=GLUSTER_VOLUMES=testvolume  --param=GLUSTER_USER=adminuser --param=GLUSTER_PASSWORD=itsmine --param=VOLUME_CAPACITY=2Gi      
--> Deploying template "storage-project/glusters3template" for "glusters3template.json" to project storage-project

     glusters3template
     ---------
     Gluster s3 service template


     * With parameters:
        * Gluster volume=testvolume
        * Gluster user=adminuser
        * Gluster user authentication=itsmine
        * Volume capacity=2Gi

--> Creating resources ...
    pod "glusters3" created
    service "glusters3service" created
    persistentvolumeclaim "glusterfs-claim" created
    persistentvolumeclaim "glusterfs-claim-meta" created
--> Success
    Run 'oc status' to view your app.
```


```
[root@master template]# oc get pods -o wide 
NAME                             READY     STATUS    RESTARTS   AGE       IP             NODE
glusterfs-1nmdp                  1/1       Running   0          4d        10.70.42.234   node3
glusterfs-5k7dk                  1/1       Running   0          4d        10.70.42.4     node2
glusterfs-85qds                  1/1       Running   0          4d        10.70.42.5     node1
glusters3                        1/1       Running   0          4m        10.130.0.29    node3
heketi-1-m8817                   1/1       Running   0          4d        10.130.0.19    node3
storage-project-router-1-2816m   1/1       Running   0          4d        10.70.42.234   node3
```

```
[root@master template]# oc get svc
NAME                                     CLUSTER-IP       EXTERNAL-IP   PORT(S)                   AGE
glusterfs-cluster                        172.30.99.166    <none>        1/TCP                     5d
glusterfs-dynamic-glusterfs-claim        172.30.45.160    <none>        1/TCP                     15m
glusterfs-dynamic-glusterfs-claim-meta   172.30.131.93    <none>        1/TCP                     15m
glusters3service                         172.30.167.137   <none>        8080/TCP                  16m
heketi                                   172.30.94.14     <none>        8080/TCP                  5d
heketi-storage-endpoints                 172.30.255.156   <none>        1/TCP                     5d
storage-project-router                   172.30.203.52    <none>        80/TCP,443/TCP,1936/TCP   6d
```

```
[root@master template]# oc get routes 
NAME              HOST/PORT                                                            PATH      SERVICES           PORT      TERMINATION   WILDCARD
glusters3object   glusters3object-storage-project.cloudapps.mystorage.com ... 1 more             glusters3service   <all>                   None
heketi            heketi-storage-project.cloudapps.mystorage.com ... 1 more                      heketi             <all>                   None
```

# Testing

### Get url of glusters3object route which exposes the s3 object storage interface
```
s3_storage_url=$(oc get routes   | grep glusters3object  | awk '{print $2}')
```

We will be using this url for accessing s3 object storage.


### s3curl.pl for testing
Download s3curl from here [s3curl](https://aws.amazon.com/code/128)

We are going to make use of s3curl.pl for verification. 

Update s3curl.pl perl script with glusters3object url which we retreived above.

For example:

my @endpoints = ( 'glusters3object-storage-project.cloudapps.mystorage.com');


### Verify put of a Bucket
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  --put /dev/null  -- -k -v  http://$s3_storage_url/bucket1

### Verify object put request. Create a simple file with some content
touch my_object.jpg
echo \"Hello Gluster from OpenShift - for S3 access demo\" > my_object.jpg
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --put  my_object.jpg  -- -k -v -s http://$s3_storage_url/bucket1/my_object.jpg

### Verify listing objects in the container 
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -k -v -s http://$s3_storage_url/bucket1/

### Verify object get request
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -o test_object.jpg http://$s3_storage_url/bucket1/my_object.jpg

### Verify received object
cat test_object.jpg

### Verify object delete request
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --delete  --  http://$s3_storage_url/bucket1/my_object.jpg

### Verify listing of objects 
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -k -v -s http://$s3_storage_url/bucket1/

### Verify bucket delete request
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --delete  --  http://$s3_storage_url/bucket1

