#!/bin/sh

export ANSIBLE_TIMEOUT=60
vagrant up --no-provision $@ \
    && vagrant provision
