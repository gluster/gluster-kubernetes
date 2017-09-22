# Gluster S3 object storage as native app. on OpenShift

## Prerequisites

* OpenShift setup is up with master and nodes ready.

* cns-deploy tool has been run and heketi service is ready.

## Deployment

### 1. Provide the backend store

The gluster-s3 service requires there be at least two GlusterFS volumes
available for its use, one to store the object data and another for the
object meta-data. In this example, we will create a new StorageClass to
dynamically provision these two volumes on our pre-existing GlusterFS cluster.

#### Create a StorageClass

In our example, we have set up heketi to require a secret key for the admin user. A StorageClass created to use such a heketi instance needs a Secret that contains the admin key. This Secret is not needed if heketi is not configured to use an admin key.
Replace `NAMESPACE` and `ADMIN_KEY` parameters with your configuration.
* `NAMESPACE` is the project
* `ADMIN_KEY` is used for authorization to access Heketi service.

```
oc create secret generic heketi-${NAMESPACE}-admin-secret --from-literal=key=${ADMIN_KEY} --type=kubernetes.io/glusterfs
```

As an optional step, the Secret can be labelled. This is useful to be able to select the secret as part of a general query like `oc get
--selector=glusterfs` and allows the secret to be removed programatically by the `gk-deploy` tool.

Replace `NAMESPACE` parameter with your configuration.

```
oc label --overwrite secret heketi-${NAMESPACE}-admin-secret glusterfs=s3-heketi-${NAMESPACE}-admin-secret gluster-s3=heketi-${NAMESPACE}-admin-secret
```

Create a GlusterFS StorageClass as below:
* `HEKETI_URL` is the URL to access GlusterFS cluster.
* `NAMESPACE` is the project.
* `STORAGE_CLASS` is the new StorageClass name provided by admin.

```
sed  -e 's/${HEKETI_URL}/heketi-store-project1.cloudapps.mystorage.com/g'  -e 's/${STORAGE_CLASS}/gluster-s3-store/g' -e 's/${NAMESPACE}/store-project1/g' deploy/ocp-templates/gluster-s3-storageclass.yaml | oc create -f -
```

Available at
[gluster-s3-storageclass.yaml](../../../deploy/ocp-templates/gluster-s3-storageclass.yaml)

#### Create backend PVCs

Now, create PVCs using the StorageClass.
* Replace `STORAGE_CLASS` with the above created one
* Adjust `VOLUME_CAPACITY` as per your needs in GBs.

```
sed -e 's/${VOLUME_CAPACITY}/2Gi/g'  -e  's/${STORAGE_CLASS}/gluster-s3-store/g'  deploy/ocp-templates/gluster-s3-pvcs.yaml | oc create -f -
persistentvolumeclaim "gluster-s3-claim" created
persistentvolumeclaim "gluster-s3-meta-claim" created
```

Available at
[gluster-s3-pvcs.yaml](../../../deploy/ocp-templates/gluster-s3-pvcs.yaml)

### 2. Start gluster-s3 service

Launch S3 storage service. Set `S3_ACCOUNT` name, `S3_USER` name, `S3_PASSWORD` according to the user wish. `S3_ACCOUNT` is the S3 account which will be created and associated with GlusterFS volume. `S3_USER` is the user created to access the above account and `S3_PASSWORD` is for Authorization of the S3 user.
`PVC` and `META_PVC` are persistentvolumeclaim(s) obtained from above step.

### For example:

```
 oc new-app  deploy/ocp-templates/gluster-s3-template.yaml \
--param=S3_ACCOUNT=testvolume  --param=S3_USER=adminuser \
--param=S3_PASSWORD=itsmine --param=PVC=gluster-s3-claim \
--param=META_PVC=gluster-s3-meta-claim
--> Deploying template "store-project1/gluster-s3" for "deploy/ocp-templates/gluster-s3-template.yaml" to project store-project1

     gluster-s3
     ---------
     Gluster s3 service template


     * With parameters:
        * S3 Account Name=testvolume
        * S3 User=adminuser
        * S3 User Password=itsmine
        * Primary GlusterFS-backed PVC=gluster-s3-claim
        * Metadata GlusterFS-backed PVC=gluster-s3-meta-claim

--> Creating resources ...
    service "gluster-s3-service" created
    route "gluster-s3-route" created
    deploymentconfig "gluster-s3-dc" created
--> Success
    Run 'oc status' to view your app.
```

Available at:
[gluster-s3-template.yaml](../../../deploy/ocp-templates/gluster-s3-template.yaml)


### 3. Verify gluster-s3 resources

Use the following commands to verify the deployment was succesful.

```
# oc get pods -o wide
NAME                             READY     STATUS    RESTARTS   AGE       IP             NODE
glusterfs-1nmdp                  1/1       Running   0          4d        10.70.42.234   node3
glusterfs-5k7dk                  1/1       Running   0          4d        10.70.42.4     node2
glusterfs-85qds                  1/1       Running   0          4d        10.70.42.5     node1
gluster-s3                       1/1       Running   0          4m        10.130.0.29    node3
heketi-1-m8817                   1/1       Running   0          4d        10.130.0.19    node3
storage-project-router-1-2816m   1/1       Running   0          4d        10.70.42.234   node3
```

```
# oc get service gluster-s3-service
NAME                 CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
gluster-s3-service   172.30.121.75   <none>        8080/TCP   1m

```

```
# oc get route gluster-s3-route
NAME               HOST/PORT                                                             PATH      SERVICES             PORT      TERMINATION   WILDCARD
gluster-s3-route   gluster-s3-route-storage-project.cloudapps.mystorage.com ... 1 more             gluster-s3-service   <all>                   None

```

# Testing


### Get url of glusters3object route which exposes the s3 object storage interface
```
s3_storage_url=$(oc get routes   | grep "gluster.*s3"  | awk '{print $2}')
```

We will be using this url for accessing s3 object storage.


### s3curl.pl for testing
Download s3curl from here [s3curl](https://aws.amazon.com/code/128)

We are going to make use of s3curl.pl for verification.

s3curl.pl requires the presence of `Digest::HMAC_SHA1` and `Digest::MD5`.
On Red Hat-based OSes, you can install the `perl-Digest-HMAC` package to get this.

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
