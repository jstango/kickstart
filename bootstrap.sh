#!/bin/bash

# Kickstart: VM Bootstrap Script
# Cross-platform, Idempotent, and AI/ML friendly.

set -e

# --- Helper Functions ---

log() {
    echo -e "\033[1;32m[KICKSTART]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
    exit 1
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# --- OS Detection ---

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    error "Cannot detect OS distribution. /etc/os-release not found."
fi

log "Detected OS: $OS"

case "$OS" in
    ubuntu|debian|mint)
        PKG_MGR="apt-get"
        INSTALL_CMD="sudo apt-get install -y"
        UPDATE_CMD="sudo apt-get update"
        ;;
    fedora|rhel|centos|rocky)
        PKG_MGR="dnf"
        INSTALL_CMD="sudo dnf install -y"
        UPDATE_CMD="sudo dnf check-update || true"
        ;;
    slackware|unraid)
        PKG_MGR="slackpkg"
        INSTALL_CMD="sudo slackpkg -batch=on -default_answer=y install"
        UPDATE_CMD="sudo slackpkg update"
        ;;
    *)
        warn "Unsupported or untested OS: $OS. Skipping system package manager checks."
        PKG_MGR="none"
        INSTALL_CMD=":"
        UPDATE_CMD=":"
        ;;
esac

# --- System Packages ---

log "Updating package lists..."
$UPDATE_CMD

install_system_pkg() {
    if ! check_cmd "$1"; then
        log "Installing $1..."
        $INSTALL_CMD "$1"
    else
        log "$1 is already installed."
    fi
}

# Map common package names if they differ
# eza might be named eza or exa
if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    # eza often needs a separate repo on older debian/ubuntu
    if ! check_cmd "eza"; then
        log "Adding eza repository..."
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
        sudo apt-get update
    fi
elif [ "$OS" == "slackware" ] || [ "$OS" == "unraid" ]; then
    # eza is usually not in main slackware repos, use slackbuilds or binary
    if ! check_cmd "eza"; then
        log "Installing eza binary for Slackware/Unraid..."
        EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
        wget -qO eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
        tar -xzf eza.tar.gz
        sudo mv eza /usr/local/bin/
        rm eza.tar.gz
    fi
fi

packages=("tmux" "nvim" "curl" "git" "nvtop" "eza")
for pkg in "${packages[@]}"; do
    # Special case for nvim command name vs package name
    if [ "$pkg" == "nvim" ]; then
        if ! check_cmd "nvim"; then
            install_system_pkg "neovim"
        else
            log "neovim is already installed."
        fi
    else
        install_system_pkg "$pkg"
    fi
done

# --- Node.js & Gemini CLI ---

if ! check_cmd "node"; then
    log "Installing Node.js via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
    $INSTALL_CMD nodejs
else
    log "Node.js is already installed."
fi

if ! check_cmd "gemini"; then
    log "Installing Gemini CLI..."
    sudo npm install -g @google/gemini-cli
else
    log "Gemini CLI is already installed."
fi

# --- Starship ---

if ! check_cmd "starship"; then
    log "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
else
    log "Starship is already installed."
fi

# --- Miniconda ---

if ! check_cmd "conda"; then
    log "Installing Miniconda..."
    CONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
    curl -O https://repo.anaconda.com/miniconda/$CONDA_INSTALLER
    bash $CONDA_INSTALLER -b -u
    rm $CONDA_INSTALLER
    ~/miniconda3/bin/conda init bash
else
    log "Conda is already installed."
fi

# --- Configuration & .bashrc ---

log "Setting up configurations..."

mkdir -p ~/.config
mkdir -p ~/.config/nvim

# Symlink configs from repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -sf "$REPO_DIR/config/starship.toml" ~/.config/starship.toml
ln -sf "$REPO_DIR/config/.tmux.conf" ~/.tmux.conf
ln -sf "$REPO_DIR/config/nvim/init.lua" ~/.config/nvim/init.lua

# Install Neovim Tokyonight theme
TOKYONIGHT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/themes/start/tokyonight.nvim"
if [ ! -d "$TOKYONIGHT_DIR" ]; then
    log "Installing Tokyonight colorscheme for Neovim..."
    mkdir -p "$(dirname "$TOKYONIGHT_DIR")"
    git clone https://github.com/folke/tokyonight.nvim.git "$TOKYONIGHT_DIR"
fi

# Update .bashrc
BASHRC="$HOME/.bashrc"

add_to_bashrc() {
    if ! grep -qF "$1" "$BASHRC"; then
        log "Adding '$1' to .bashrc"
        echo "$1" >> "$BASHRC"
    fi
}

# Prompt for Gemini API Key
if ! grep -qF "export GEMINI_API_KEY=" "$BASHRC"; then
    echo -ne "\033[1;34m[SETUP]\033[0m Enter your Gemini API key (or press enter to skip): "
    read -r GEMINI_API_KEY_INPUT
    if [ -n "$GEMINI_API_KEY_INPUT" ]; then
        add_to_bashrc "export GEMINI_API_KEY=\"$GEMINI_API_KEY_INPUT\""
    fi
fi

add_to_bashrc 'eval "$(starship init bash)"'
add_to_bashrc "alias ls='eza --icons'"
add_to_bashrc "alias ll='eza -lh --icons'"
add_to_bashrc "alias la='eza -a --icons'"

log "Bootstrap complete! Please restart your shell or run 'source ~/.bashrc'"
