#!/bin/bash
set -euo pipefail

# Function for logging
log() {
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') === $1"
}

log "Script started"
log "Environment check:"
echo "Current user: $(whoami)"
echo "SUDO_USER: ${SUDO_USER}"
echo "Current directory: $(pwd)"
echo "Available disk space:"
df -h /home

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then 
    log "Error: Script must be run as root"
    exit 1
fi

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

log "Installing initial packages"
apt-get update
apt-get install curl openssl -y

log "=== Starting Homebrew Installation ==="
log "Checking Homebrew prerequisites:"
echo "curl version: $(curl --version)"
echo "openssl version: $(openssl version)"
echo "Homebrew directory permissions before install:"
ls -la /home/linuxbrew 2>/dev/null || echo "Homebrew directory does not exist yet"

# Install Homebrew
log "Installing Homebrew..."
sudo -u "${SUDO_USER}" NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to the user's shell env
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    log "=== Homebrew Installation Complete ==="
    log "Homebrew directory structure:"
    ls -la /home/linuxbrew/.linuxbrew
    log "Homebrew Cellar directory:"
    ls -la /home/linuxbrew/.linuxbrew/Cellar 2>/dev/null || echo "Cellar directory does not exist yet"
    
    # Set proper permissions for Homebrew directory
    log "Setting permissions for Homebrew directory..."
    chown -R "${SUDO_USER}:${SUDO_USER}" /home/linuxbrew/.linuxbrew
    
    log "Permissions after chown:"
    ls -la /home/linuxbrew/.linuxbrew
    log "Cellar permissions after chown:"
    ls -la /home/linuxbrew/.linuxbrew/Cellar 2>/dev/null || echo "Cellar directory does not exist yet"
    
    # Add Homebrew to environment for the current user
    log "Adding Homebrew to shell configuration..."
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.bashrc"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/${SUDO_USER}/.zshrc"
    
    # Set up Homebrew environment for the current shell
    log "Setting up Homebrew environment..."
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    
    log "=== Installing yq ==="
    log "Homebrew environment:"
    env | grep HOMEBREW
    log "Homebrew version:"
    brew --version
    
    # Install yq as the target user with proper environment setup
    log "Starting yq installation as ${SUDO_USER}..."
    sudo -u "${SUDO_USER}" bash -c '
        set -x
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
        echo "=== Starting yq installation ==="
        echo "Current user: $(whoami)"
        echo "Homebrew path: $(which brew)"
        echo "Homebrew version: $(brew --version)"
        echo "Target directory permissions:"
        ls -la /home/linuxbrew/.linuxbrew/Cellar
        echo "Available disk space:"
        df -h /home
        echo "Starting brew install yq..."
        brew install yq
    '
else
    log "Error: Homebrew installation directory not found"
    exit 1
fi

# Function to read YAML values using yq
read_yaml() {
    local file=$1
    local path=$2
    log "Reading YAML from $file at path $path"
    sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"; yq eval \"$path\" \"$file\""
}

# Function to read secrets from YAML
read_secrets() {
    local file=$1
    local path=$2
    log "Reading secrets from $file at path $path"
    sudo -u "${SUDO_USER}" bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"; yq eval \"$path\" \"$file\""
}

# Change to the correct directory
log "Changing to rinzler directory..."
cd "/home/${SUDO_USER}/rinzler"
log "Current directory: $(pwd)"

# Read packages list from bootstrap.yaml
log "Reading packages from bootstrap.yaml..."
PACKAGES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.packages | join(\" \")")
log "Packages to install: ${PACKAGES}"

# Read configuration values from bootstrap.yaml
log "Reading configuration values from bootstrap.yaml..."
DOCKGE_STACKS_DIR=$(read_yaml "config/bootstrap.yaml" ".bootstrap.dockge_stacks_dir")
TIMEZONE=$(read_yaml "config/bootstrap.yaml" ".bootstrap.timezone")
PUID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.puid")
PGID=$(read_yaml "config/bootstrap.yaml" ".bootstrap.pgid")
ZFS_POOL=$(read_yaml "config/bootstrap.yaml" ".bootstrap.zfs_pool")
WIREGUARD_ADDRESSES=$(read_yaml "config/bootstrap.yaml" ".bootstrap.wireguard.addresses")

# Read GitHub configuration
log "Reading GitHub configuration..."
GITHUB_OWNER=$(read_yaml "config/runner.yaml" ".runner.github.owner")
REPOSITORY_NAME=$(read_yaml "config/runner.yaml" ".runner.github.repo_name")
GITHUB_SSH_USER=$(read_yaml "config/runner.yaml" ".runner.github.ssh.user")
GITHUB_SERVER_HOST=$(read_yaml "config/runner.yaml" ".runner.github.ssh.server_host")

# Read Pi-hole configuration
log "Reading Pi-hole configuration..."
PIHOLE_URL=$(read_yaml "config/pihole.yaml" ".pihole.url")

# Read UniFi configuration
log "Reading UniFi configuration..."
UNIFI_CONTROLLER_URL=$(read_yaml "config/unifi.yaml" ".unifi.controller_url")
UNIFI_SITE=$(read_yaml "config/unifi.yaml" ".unifi.site")

# Read secrets
log "Reading secrets from example.yaml..."
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
log "Installing required packages..."
apt-get update
IFS=' ' read -ra PACKAGES_ARRAY <<< "${PACKAGES}"
apt-get install -y "${PACKAGES_ARRAY[@]}"

# Install tfenv
log "Installing tfenv..."
TFENV_DIR="/home/${GITHUB_SSH_USER}/.tfenv"

# Ensure dependencies
command -v git >/dev/null || { log "Error: git is required"; exit 1; }

# Clone tfenv if not already present
if [[ ! -d "$TFENV_DIR" ]]; then
    log "Cloning tfenv repository..."
    git clone --depth=1 https://github.com/tfutils/tfenv.git "$TFENV_DIR"
fi

# Add tfenv to PATH if not already
if ! grep -q 'tfenv/bin' <<<"$PATH"; then
    log "Adding tfenv to PATH..."
    export PATH="$TFENV_DIR/bin:$PATH"
    echo "export PATH=\"$TFENV_DIR/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.bashrc"
    echo "export PATH=\"$TFENV_DIR/bin:\$PATH\"" >> "/home/${GITHUB_SSH_USER}/.zshrc"
fi

# Install Terraform 1.10.4 non-interactively
log "Installing Terraform 1.10.4..."
tfenv install 1.10.4
tfenv use 1.10.4

# Install pyenv
log "Installing pyenv..."
curl https://pyenv.run | bash

# Set up ZSH and Powerlevel10k
log "Setting up ZSH and Powerlevel10k..."
# Install Oh My Zsh (non-interactive)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k
log "Installing Powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/themes/powerlevel10k"

# Install ZSH plugins
log "Installing ZSH plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "/home/${GITHUB_SSH_USER}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# Set ZSH as default shell (non-interactive)
log "Setting ZSH as default shell..."
chsh -s "$(which zsh)" "${GITHUB_SSH_USER}"

# Install Nerd Fonts
log "Installing Nerd Fonts..."
mkdir -p "/home/${GITHUB_SSH_USER}/.local/share/fonts"
cd "/home/${GITHUB_SSH_USER}/.local/share/fonts"

# Get the latest release version
log "Getting latest Nerd Fonts release..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
log "Latest release: ${LATEST_RELEASE}"

# Download and extract IBM Plex Mono
log "Downloading IBM Plex Mono..."
curl -L -o "IBMPlexMono.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST_RELEASE}/IBMPlexMono.zip"
unzip -o "IBMPlexMono.zip" "BlexMonoNerdFontMono-*.ttf" -d "/home/${GITHUB_SSH_USER}/.local/share/fonts/"
rm "IBMPlexMono.zip"

# Set proper permissions for the font files
log "Setting font file permissions..."
chown -R "${GITHUB_SSH_USER}:${GITHUB_SSH_USER}" "/home/${GITHUB_SSH_USER}/.local/share/fonts"
chmod 644 "/home/${GITHUB_SSH_USER}/.local/share/fonts/"*.ttf

# Update font cache for Ubuntu
log "Updating font cache..."
fc-cache -f -v

# Create .zshrc with Powerlevel10k configuration
log "Creating .zshrc configuration..."
cat > "/home/${GITHUB_SSH_USER}/.zshrc" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Add Homebrew to PATH
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Configure pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
EOF

# Create a basic p10k configuration
log "Creating p10k configuration..."
cat > "/home/${GITHUB_SSH_USER}/.p10k.zsh" << 'EOF'
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

# Configure Docker
log "Configuring Docker..."
systemctl enable docker
systemctl start docker

# Start services
log "Starting services..."
cd "/home/${GITHUB_SSH_USER}/compose/${repo_path}"
sudo -u "${GITHUB_SSH_USER}" docker-compose up -d

log "Bootstrap script completed successfully!" 