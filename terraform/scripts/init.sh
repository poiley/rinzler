#!/bin/bash 

# Set the script to exit on error
set -e

BRANCH="test"
REPO="rinzler"
GH_USER="poiley"

# Reset Path
cd $HOME

# Clone the repository
git clone -b $BRANCH https://github.com/$GH_USER/$REPO  
cd $REPO 
clear

# Run the bootstrap script
sudo ./terraform/scripts/bootstrap-init.sh 