#!/bin/bash

#sudo yum install -y pv > /dev/null 2>&1

. ./util.sh

desc "show kubernetes nodes"
run "kubectl get nodes,pods"

cd deploy || exit 1

HEKETI_CLI_SERVER=$(kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}')
export HEKETI_CLI_SERVER

desc "test heketi with curl"
run "kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}' ; echo"
echo "HEKETI_CLI_SERVER: ${HEKETI_CLI_SERVER}"
run "curl ${HEKETI_CLI_SERVER}/hello ; echo"

desc "test heketi-cli"
run "heketi-cli cluster list"
run "heketi-cli node list"
run "heketi-cli volume list"

desc "create a volume"
run "heketi-cli volume create --size=2 | tee volume-create.out"
volumeId=$(grep "Volume Id"  volume-create.out  | awk '{print $3}')
run "heketi-cli volume list"
run "heketi-cli volume info ${volumeId}"

desc "delete the volume again"
run "heketi-cli volume delete ${volumeId}"
run "heketi-cli volume list"

desc "demo-test-heketi: done"
