#
# This image is to be used with the heketi-turnkey deployment.
# See https://github.com/lenartj/gluster-kubernetes/tree/master/deploy/kube-templates/heketi-turnkey.yaml
#
# The docker image includes:
# - gk-deploy from the gluster-kubernetes project
# - heketi-cli binary built from source (github master)
# - kubectl binary from apt.kubernetes.io
# - run time dependencies for gk-deploy
#
FROM debian:sid
RUN apt-get update \
 && apt-get install -y python-minimal curl \
 && mkdir /build \
 && cp -ax /bin /dev /etc /lib /lib32 /lib64 /libx32 /sbin /tmp /usr /var /build \
 && chroot /build bash -c "\
   set -xe; \
   apt-get update; \
   apt-get install -y \
     apt-transport-https git gnupg golang make; \
   curl -O https://packages.cloud.google.com/apt/doc/apt-key.gpg;\
   apt-key add apt-key.gpg; \
   echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" \
     >/etc/apt/sources.list.d/kubernetes.list; \
   apt-get update; \
   apt-get install -y kubectl; \
   export GOPATH=/tmp/golang; \
   export PATH=\"\$GOPATH/bin:\$PATH\"; \
   mkdir -pv \$GOPATH/bin; \
   go get -x github.com/tools/godep; \
   go get -x github.com/heketi/heketi/client/cli/go/cmds; \
   make -C \$GOPATH/src/github.com/heketi/heketi/client/cli/go" \
 && install -v \
   /build/usr/bin/kubectl \
   /build/tmp/golang/src/github.com/heketi/heketi/client/cli/go/heketi-cli \
   /usr/local/bin/ \
 && rm -r /build
COPY . /opt/gk-deploy
WORKDIR /opt/gk-deploy
