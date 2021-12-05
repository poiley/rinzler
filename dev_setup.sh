#!/bin/bash

# Install pre-requisites
sudo apt update
sudo apt install -y build-essential git curl

# Configuration
EMAIL="benjpoile@gmail.com"
REPOSITORY="rinzler"
USER="poiley"
git config --global user.email $EMAIL
git config --global user.name $USER

# Install Brew 
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
test -r ~/.bash_profile && echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >>~/.bash_profile
echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >>~/.profile

# Install Github CLI
brew install gcc gh

# Create SSH Key
ssh-keygen -t rsa -b 4096 -C $EMAIL

# Authenticate with Github
gh auth login

# Clone repository
gh repo clone $USER/$REPOSITORY
