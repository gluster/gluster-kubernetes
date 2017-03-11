#!/bin/bash

#sudo yum install -y pv > /dev/null 2>&1

. ./util.sh

run "kubectl get nodes,all,ep"

desc "demo-status: done"
