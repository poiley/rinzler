#!/bin/bash
set -euo pipefail

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

# Install required packages first
apt-get update
# Convert space-separated list to array and install each package
IFS=' ' read -ra PACKAGES <<< "${PACKAGES}"
apt-get install -y "${PACKAGES[@]}"

# Note: SUDO_USER is used temporarily as the user before GITHUB_SSH_USER is read. Realistically, the values will be the same.

# Change to the correct directory
cd "/home/${SUDO_USER}/rinzler"

# Install Homebrew
sudo -u "${SUDO_USER}" NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to the user's shell env
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.bashrc"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.zshrc"
fi

# Install yq as the target user with Homebrew in PATH
sudo -u "${SUDO_USER}" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; brew install yq'


# Function to read YAML values using yq
read_yaml() {
    local file=$1
    local path=$2
    yq eval "$path" "$file"
}

# Function to read secrets from YAML
read_secrets() {
    local file=$1
    local path=$2
    yq eval "$path" "$file"
}

# Read packages list from bootstrap.yaml
PACKAGES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.packages | join(\" \")")

# Read configuration values from bootstrap.yaml
DOCKGE_STACKS_DIR=$(read_yaml "config/bootstrap.yaml" ".bootstrap.dockge_stacks_dir")
TIMEZONE=$(read_yaml "config/bootstrap.yaml" ".bootstrap.timezone")
PUID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.puid")
PGID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.pgid")
ZFS_POOL=$(read_yaml "config/bootstrap.yaml" ".bootstrap.zfs_pool")
WIREGUARD_ADDRESSES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.wireguard.addresses")

# Read GitHub configuration
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")
GITHUB_SERVER_HOST=$(read_yaml "config/runner.yaml" ".runner.github.ssh.server_host")

# Read Pi-hole configuration
PIHOLE_URL=$(read_yaml "config/pihole.yaml" ".pihole.url")

# Read UniFi configuration
UNIFI_CONTROLLER_URL=$(read_yaml "config/unifi.yaml" ".unifi.controller_url")
UNIFI_SITE=$(read_yaml "config/unifi.yaml" ".unifi.site")

# Read secrets (assuming they're in config/secrets/example.yaml)
BASIC_AUTH_HEADER=$(read_secrets "config/secrets/example.yaml" ".bootstrap.basic_auth_header")
WIREGUARD_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".bootstrap.wireguard.private_key")
PIHOLE_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".pihole.password")
PIHOLE_API_TOKEN=$(read_secrets "config/secrets/example.yaml" ".pihole.api_token")
GITHUB_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.token")
GITHUB_RUNNER_TOKEN=$(read_secrets "config/secrets/example.yaml" ".github.runner_token")
GITHUB_SSH_PRIVATE_KEY=$(read_secrets "config/secrets/example.yaml" ".github.ssh.private_key")
UNIFI_USERNAME=$(read_secrets "config/secrets/example.yaml" ".unifi.username")
UNIFI_PASSWORD=$(read_secrets "config/secrets/example.yaml" ".unifi.password")
UNIFI_API_KEY=$(read_secrets "config/secrets/example.yaml" ".unifi.api_key")

# Install required packages
apt-get update
# Convert space-separated list to array and install each package
IFS=' ' read -ra PACKAGES <<< "$@"
apt-get install -y "${PACKAGES[@]}"

#!/usr/bin/env bash
set -euo pipefail

# Directory where tfenv will be installed (default to ~/.tfenv)
TFENV_DIR="${GITHUB_SSH_USER}/.tfenv"

# Ensure dependencies
command -v git >/dev/null || { echo "git is required"; exit 1; }

# Clone tfenv if not already present
if [[ ! -d "$TFENV_DIR" ]]; then
    git clone --depth=1 https://github.com/tfutils/tfenv.git "$TFENV_DIR"
fi

# Add tfenv to PATH if not already
if ! grep -q 'tfenv/bin' <<<"$PATH"; then
    export PATH="$TFENV_DIR/bin:$PATH"
    echo "export PATH=\"$TFENV_DIR/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.bashrc"
    echo "export PATH=\"$TFENV_DIR/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.zshrc"
fi

# Install Terraform 1.10.4 non-interactively
tfenv install 1.10.4
tfenv use 1.10.4

# Install pyenv
curl https://pyenv.run | bash

# Set up ZSH and Powerlevel10k
# Install Oh My Zsh (non-interactive)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/themes/powerlevel10k"

# Install ZSH plugins
git clone https://github.com/zsh-users/zsh-autosuggestions "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# Set ZSH as default shell (non-interactive)
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}"

# Install Nerd Fonts
mkdir -p /home/$GITHUB_SSH_USER/.local/share/fonts
cd /home/$GITHUB_SSH_USER/.local/share/fonts
curl -fLo "Hack Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf
curl -fLo "FiraCode Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete.ttf

# Update font cache for Ubuntu
fc-cache -f -v

# Create .zshrc with Powerlevel10k configuration
cat > /home/$GITHUB_SSH_USER/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Add Homebrew to PATH
test -d /home/$GITHUB_SSH_USER/linuxbrew && eval "$(/home/$GITHUB_SSH_USER/linuxbrew/bin/brew shellenv)"

# Configure pyenv
export PYENV_ROOT="/home/$GITHUB_SSH_USER/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f /home/$GITHUB_SSH_USER/.p10k.zsh ]] || source /home/$GITHUB_SSH_USER/.p10k.zsh
EOF

# Create a basic p10k configuration to avoid first-run prompt
cat > /home/$GITHUB_SSH_USER/.p10k.zsh << 'EOF'
# Basic Powerlevel10k configuration
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir                     # current directory
  vcs                    # git status
  newline                # \n
  prompt_char            # prompt symbol
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status                 # exit code of the last command
  command_execution_time # duration of the last command
  background_jobs       # presence of background jobs
  time                  # current time
)

# Basic color scheme
typeset -g POWERLEVEL9K_MODE=nerdfont-complete
typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
EOF

chsh -s "$(command -v zsh)" "${GITHUB_SSH_USER}"

# Configure Docker
systemctl enable docker
systemctl start docker

# Start services
cd "/home/$GITHUB_SSH_USER/compose/${repo_path}"
sudo -u "${GITHUB_SSH_USER}" docker-compose up -d 