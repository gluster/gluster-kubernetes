#!/bin/bash

#sudo yum install -y pv > /dev/null 2>&1

. ./util.sh

desc "show kubernetes nodes"
run "kubectl get nodes"

desc "show pods"
run "kubectl get pods"

cd deploy || exit 1

desc "look at topology"
run "vim topology.json"

desc "run gk-deploy"
run "./gk-deploy -g topology.json"

desc "show pods etc"
run "kubectl get nodes,all,ep"

desc "demo-deploy: done"
