#!/bin/bash

echo "installing pv"
sudo yum install -y pv > /dev/null 2>&1
echo "preparing .vimrc"
echo "set bg=dark" >> ~/.vimrc
echo "done"
