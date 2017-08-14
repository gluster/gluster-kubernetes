# Gluster S3 object storage as native app. on OpenShift

## Prerequisites

  OpenShift setup is up with master and nodes ready.

  cns-deploy tool is ran and heketi service is ready




## First create a storageclass

Create a GlusterFS StorageClass as below, replacing the `rest` parameters with your configuration:

```
oc create -f ./gluster-s3-storageclass.yaml
```

Available at 
[gluster-s3-storageclass.yaml](./gluster-s3-storageclass.yaml)

## Start glusters3 service using template

```
oc new-app gluster-s3-template.yaml  --param=S3_ACCOUNT=testvolume  --param=S3_USER=adminuser --param=S3_PASSWORD=itsmine --param=VOLUME_CAPACITY=2Gi
```

Note: adjust parameters according to your needs.


If you wish to make use of a GlusterFS StorageClass other than `s3storageclass`, add another parameter of the form:


```
--param=STORAGE_CLASS=<your storage class name>
```



Available at:
[gluster-s3-template.yaml](./gluster-s3-template.yaml)

### For example:


```
[root@master template]# oc new-app glusters3template.json  --param=S3_ACCOUNT=testvolume  --param=S3_USER=adminuser --param=S3_PASSWORD=itsmine --param=VOLUME_CAPACITY=2Gi
--> Deploying template "storage-project/glusters3template" for "glusters3template.json" to project storage-project

     glusters3template
     ---------
     Gluster s3 service template


     * With parameters:
        * S3 account=testvolume
        * S3 user=adminuser
        * S3 user authentication=itsmine
        * Volume capacity=2Gi

--> Creating resources ...
    service "glusters3service" created
    route "glusters3object" created
    persistentvolumeclaim "glusterfs-s3-claim" created
    persistentvolumeclaim "glusterfs-s3-claim-meta" created
    deploymentconfig "glusters3" created
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

Note: Package perl-Digest-HMAC.noarch, a dependency package for s3curl also needs to be installed.
Install the same using your package manager.

Now, update s3curl.pl perl script with glusters3object url which we retreived above.

For example:

```
my @endpoints = ( 'glusters3object-storage-project.cloudapps.mystorage.com');
```


### Verify put of a Bucket
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  --put /dev/null  -- -k -v  http://$s3_storage_url/bucket1
```


Sample output:

```
# s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --put /dev/null  --  -k -v  http://glusters3object-storage-project.cloudapps.mystorage.com/bucket1
s3curl: Found the url: host=glusters3object-storage-project.cloudapps.mystorage.com; port=; uri=/bucket1; query=;
s3curl: ordinary endpoint signing case
s3curl: StringToSign='PUT\n\n\nFri, 30 Jun 2017 05:19:41 +0000\n/bucket1'
s3curl: exec curl -H Date: Fri, 30 Jun 2017 05:19:41 +0000 -H Authorization: AWS testvolume:adminuser:5xMXB7uyz51dUcephS6g1dVFwCM= -L -H content-type:  -T /dev/null -k -v http://glusters3object-storage-project.cloudapps.mystorage.com/bucket1
* About to connect() to glusters3object-storage-project.cloudapps.mystorage.com port 80 (#0)
*   Trying 10.70.42.234...
* Connected to glusters3object-storage-project.cloudapps.mystorage.com (10.70.42.234) port 80 (#0)
> PUT /bucket1 HTTP/1.1
> User-Agent: curl/7.29.0
> Host: glusters3object-storage-project.cloudapps.mystorage.com
> Accept: */*
> Transfer-Encoding: chunked
> Date: Fri, 30 Jun 2017 05:19:41 +0000
> Authorization: AWS testvolume:adminuser:5xMXB7uyz51dUcephS6g1dVFwCM=
> Expect: 100-continue
> 
< HTTP/1.1 200 OK
< Content-Type: text/html; charset=UTF-8
< Location: bucket1
< Content-Length: 0
< X-Trans-Id: tx188fd6bb5f41403c8d114-005955df6d
< Date: Fri, 30 Jun 2017 05:19:41 GMT
< Set-Cookie: fad43e2ce02bfea85cd465cc937029f2=0551e8024aa5cd2c9b0791109252676d; path=/; HttpOnly
< Cache-control: private
< 
* Connection #0 to host glusters3object-storage-project.cloudapps.mystorage.com left intact
```

### Verify object put request. Create a simple file with some content
```
touch my_object.jpg


echo \"Hello Gluster from OpenShift - for S3 access demo\" > my_object.jpg


s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --put  my_object.jpg  -- -k -v -s http://$s3_storage_url/bucket1/my_object.jpg
```

### Verify listing objects in the container 
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -k -v -s http://$s3_storage_url/bucket1/
```

### Verify object get request
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -o test_object.jpg http://$s3_storage_url/bucket1/my_object.jpg
```

### Verify received object
```
cat test_object.jpg
```

### Verify object delete request
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --delete -- http://$s3_storage_url/bucket1/my_object.jpg
```

### Verify listing of objects 
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine"  -- -k -v -s http://$s3_storage_url/bucket1/
```

### Verify bucket delete request
```
s3curl.pl --debug --id "testvolume:adminuser" --key "itsmine" --delete  --  http://$s3_storage_url/bucket1
```

### To add a new user to the S3 account:

#### First login to the pod
```
oc rsh <glusters3pod>
```

#### This step prepares the gluster volume where gswauth will save its metadata
```
gswauth-prep -A http://<ipaddr>:8080/auth -K gswauthkey
```

Where, `ipaddr` is the IP address of the glusters3 pod obtained from 'oc get pods -o wide'

#### To add user to account
```
gswauth-add-user -K gswauthkey -a <s3 account> <user> <password>
```
