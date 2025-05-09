#!/bin/bash

# Set non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

# Install required packages
apt-get update
# Convert space-separated list to array and install each package
IFS=' ' read -ra PACKAGES <<< "$@"
apt-get install -y "${PACKAGES[@]}"

#!/usr/bin/env bash
set -euo pipefail

# Directory where tfenv will be installed (default to ~/.tfenv)
TFENV_DIR="${HOME}/.tfenv"

# Ensure dependencies
command -v git >/dev/null || { echo "git is required"; exit 1; }

# Clone tfenv if not already present
if [[ ! -d "$TFENV_DIR" ]]; then
  git clone --depth=1 https://github.com/tfutils/tfenv.git "$TFENV_DIR"
fi

# Add tfenv to PATH if not already
if ! grep -q 'tfenv/bin' <<<"$PATH"; then
  export PATH="$TFENV_DIR/bin:$PATH"
  echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc if needed
fi

# Install Terraform 1.10.4 non-interactively
tfenv install 1.10.4
tfenv use 1.10.4

# Install Homebrew
sudo -u "$ssh_user" NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to the user's shell env
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/$ssh_user/.bashrc"
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "/home/$ssh_user/.zshrc"
fi

# Install yq as the target user with Homebrew in PATH
sudo -u "$ssh_user" bash -c 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; brew install yq'

# Install pyenv
curl https://pyenv.run | bash

# Set up ZSH and Powerlevel10k
# Install Oh My Zsh (non-interactive)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k

# Install ZSH plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Set ZSH as default shell (non-interactive)
chsh -s $(which zsh) $USER

# Install Nerd Fonts
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLo "Hack Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf
curl -fLo "FiraCode Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete.ttf

# Update font cache for Ubuntu
fc-cache -f -v

# Create .zshrc with Powerlevel10k configuration
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Add Homebrew to PATH
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Configure pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# Create a basic p10k configuration to avoid first-run prompt
cat > ~/.p10k.zsh << 'EOF'
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
systemctl enable docker
systemctl start docker

# Start services
cd "${repo_path}"
docker-compose up -d 