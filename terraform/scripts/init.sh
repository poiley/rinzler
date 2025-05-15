#!/bin/bash 

# Clone the repository
git clone -b test https://github.com/poiley/rinzler  
cd rinzler 
clear

# Run the bootstrap script
sudo ./terraform/scripts/bootstrap-init.sh 