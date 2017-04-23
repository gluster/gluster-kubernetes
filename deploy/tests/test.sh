#!/bin/bash
# Copyright (c) 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

KUBE_GLUSTER_DEAMONSET=../kube-templates/glusterfs-daemonset.yaml 
KUBE_HEKETI_DEPLOYMENT=../kube-templates/heketi-deployment.yaml
KUBE_HEKETI_SA=../kube-templates/heketi-service-account.yaml 
OCP_GLUSTER_TEMPLATE=../ocp-templates/glusterfs-template.yaml
OCP_HEKETI_TEMPLATE=../ocp-templates/heketi-template.yaml
OCP_HEKETI_SA=../ocp-templates/heketi-service-account.yaml
TOPOLOGY=../topology.json.sample

# syntax checking can not be done if file has more than one yaml context 
# so split and call check
# check kube-templates/heketi-deployment.yaml to understand what I am talking about
split_yaml_check() {
  file="${1}"
  awk '{print $0 > "file" NR}' RS='---'  ${file}
  count=$(ls -l file* | wc -l)
  for i in `seq 1 ${count}`
  do
    sed -i '1s/^/\-\-\-/' file${i}
    check "file${i}"
  done
}

# yaml syntax check
check() {
  file="${1}"
  TEST=$(python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < ${file} 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "Failed ${file}"
  fi
}

# copies the source and adds the mock source. This will be used for testing
cp ../gk-deploy gk-deploy-unit
sed -i '16s/^/\nsource mock.sh/' gk-deploy-unit

# Just to verify if the syntax is actually tested
TEST=$(python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < ./glusterfs-daemonset-wrong.yaml 2> /dev/null)
if [[ $? -ne 0 ]]; then
  echo "Found yaml syntax error in above yaml file, Syntax checking is working \\o/"
fi

# call all the yaml files and check if they exist. Also call yaml syntax checking
for i in $KUBE_GLUSTER_DEAMONSET $KUBE_HEKETI_DEPLOYMENT $KUBE_HEKETI_SA $OCP_GLUSTER_TEMPLATE $OCP_HEKETI_TEMPLATE $OCP_HEKETI_SA 
do
  if test "$(ls ${i})"
  then
	echo "$i is present"
	# Add here if the new file has more than one yaml context
        if [[ "${i}" != "${KUBE_HEKETI_DEPLOYMENT}" ]]; then
	  check "${i}"
        else
          split_yaml_check "${i}"
	fi
  fi
done

./gk-deploy-unit -y
if [[ ${?} -ne 0 ]]; then
  echo "Failed. Topology failure: check good"
fi

./gk-deploy-unit -y -c fail "${TOPOLOGY}"
if [[ ${?} -ne 0 ]]; then
  echo "Failed. cli failure: check good"
fi

./gk-deploy-unit -y -c kubectl -n invalid "${TOPOLOGY}"
if [[ ${?} -ne 0 ]]; then
  echo "Failed. NameSpace failure: check good"
fi

./gk-deploy-unit -y -n invalid "${TOPOLOGY}"
if [[ ${?} -ne 0 ]]; then
  echo "Failed. NameSpace failure without cli: check good"
fi

# This has to be moved to teardown function
rm file*
rm gk-deploy-unit

# More test will be add after mock is done
