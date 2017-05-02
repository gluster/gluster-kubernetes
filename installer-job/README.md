# gk-installer
Installer for [gluster/gluster-kubernetes](https://github.com/gluster/gluster-kubernetes)

## Usage
The installer expects that you are running the Job in the Kubernetes cluster you intend to deploy gluster-kubernetes to. It also expects that you will mount your [topology file](https://github.com/heketi/heketi/wiki/Setting-up-the-topology) to /etc/gk-deploy/topology.json (i.e. via ConfigMap)

The repo includes an example ConfigMap and Job for deployment

### Step-by-step
1. Create your [topology file](https://github.com/heketi/heketi/wiki/Setting-up-the-topology) for Heketi
2. Create the Kubernetes ConfigMap with your topology file
  `kubectl create configmap gk-install-topology --from-file=<path to your topology file>`
3. Create the Kubernetes Job to install gluster-kubernetes
  `kubectl create -f example/gk-install-job.yaml`
4. Create the Kubernetes StorageClass referencing the GlusterFS/Heketi storage
  `kubectl create -f example/gk-storage-class.yaml`

### Building and Pushing the Docker image
1. Build the image
  `docker build . -t <Docker Hub Username>/gk-installer`
2. Push the image
  `docker push <Docker Hub Username>/gk-installer`

** Note: ** To use your image you will need to update `gk-install-job.yaml` to point to your container
