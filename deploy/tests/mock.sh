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

# Mock functions for heketi
heketi-cli() {
topo=`cat ./topology-output-wrong.txt`
echo "${topo}"
}


# Mock functions for kube
kubectl() {
  req=${@}
  out=""
  check=$(assign "${req:1}" "${1}")
  if [[ "config" == "${check}" ]]; then
    out="aplo"
  elif [[ "get" == "${check}" ]]; then
    ns=$(assign "${req:1}" "${3}")
    if [[ "invalid" == "${ns}" ]]; then
      return 1
    fi
    return 0
  fi
  echo "${out}"
}

# Mock functions for ocp
oc() {
  req=${@}
  out=""
  check=$(assign "${req:1}" "${1}")
  if [[ "config" == "${check}" ]]; then
    out=`cat ./oc-context.txt`
  elif [[ "get" == "${check}" ]]; then
    ns=$(assign "${req:1}" "${3}")
    if [[ "invalid" == "${ns}" ]]; then
      return 1
    fi
    return 0
  fi
  echo "${out}"
}

# Mock funtion for type
type() {
  cli=${1}
  if [[ "kubectl" == ${cli} ]]; then
    out="kubectl is /usr/bin/kubectl"
  elif [[ "oc" == ${cli} ]]; then
    out="oc is /usr/bin/oc"
  fi
  echo "${out}"
}
