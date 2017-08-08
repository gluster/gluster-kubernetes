#!/bin/bash

sudo docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v ~/docker/registry:/var/lib/registry \
  registry:latest
