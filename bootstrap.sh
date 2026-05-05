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
    *)
        warn "Unsupported or untested OS: $OS. Attempting to use 'apt-get' as fallback."
        PKG_MGR="apt-get"
        INSTALL_CMD="sudo apt-get install -y"
        UPDATE_CMD="sudo apt-get update"
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

# Symlink configs from repo
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -sf "$REPO_DIR/config/starship.toml" ~/.config/starship.toml
ln -sf "$REPO_DIR/config/.tmux.conf" ~/.tmux.conf

# Update .bashrc
BASHRC="$HOME/.bashrc"

add_to_bashrc() {
    if ! grep -qF "$1" "$BASHRC"; then
        log "Adding '$1' to .bashrc"
        echo "$1" >> "$BASHRC"
    fi
}

add_to_bashrc 'eval "$(starship init bash)"'
add_to_bashrc "alias ls='eza --icons'"
add_to_bashrc "alias ll='eza -lh --icons'"
add_to_bashrc "alias la='eza -a --icons'"

log "Bootstrap complete! Please restart your shell or run 'source ~/.bashrc'"
