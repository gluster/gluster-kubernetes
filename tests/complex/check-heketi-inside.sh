#!/bin/bash

heketi_service=$(kubectl describe svc/heketi | grep "Endpoints:" | awk '{print $2}')
hello=$(curl "http://${heketi_service}/hello" 2>/dev/null)
if [[ "${hello}" != "Hello from Heketi" ]]; then
  output "Failed to communicate with heketi service."
  exit 1
fi
