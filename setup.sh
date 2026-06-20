#!/usr/bin/env bash
set -e

echo "=================================================="
echo "🚀 Bootstrapping Ultimate Linux Dev Workstation..."
echo "=================================================="

# Detect if we are running as root (Docker) or normal user (Host PC)
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "--> Updating system package index..."
$SUDO apt-get update -y

# Added 'lsof' to the payload
echo "--> Installing core utilities & dev packages..."
$SUDO apt-get install -y \
    git \
    curl \
    jq \
    htop \
    vim \
    lsof \
    build-essential \
    openssh-server \
    openssh-client \
    tldr \
    bash-completion

# ---------------------------------------------------------
# 1. System Tweak: Increase File Watcher Limit
# ---------------------------------------------------------
if [ -n "$SUDO" ] && [ -d "/etc/sysctl.d" ]; then
    echo "--> Optimizing Linux file-watcher limits for heavy projects..."
    echo "fs.inotify.max_user_watches=524288" | $SUDO tee /etc/sysctl.d/99-dev-tweaks.conf > /dev/null
    $SUDO sysctl --system > /dev/null || true
fi

# ---------------------------------------------------------
# 2. Docker & Docker Compose (v2)
# ---------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "--> Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    if $SUDO sh get-docker.sh; then
        rm -f get-docker.sh
    else
        rm -f get-docker.sh
        echo "❌ Docker installation failed!" >&2
        exit 1
    fi

    if [ -n "$SUDO" ]; then
        $SUDO usermod -aG docker "$USER"
        echo "Granted '$USER' permission to run Docker without sudo."
    fi
else
    echo "--> Docker is already installed. Skipping."
fi

# Apply Docker CLI tab-completion
echo "--> Applying Docker CLI tab-completion rules..."
$SUDO mkdir -p /etc/bash_completion.d
$SUDO curl -sSL https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker -o /etc/bash_completion.d/docker

# ---------------------------------------------------------
# 3. Python Environment (Astral 'uv')
# ---------------------------------------------------------
if ! command -v uv &> /dev/null; then
    echo "--> Installing 'uv' Python package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "--> 'uv' is already installed. Skipping."
fi

# ---------------------------------------------------------
# 4. Inject Dev Aliases (Safe / Idempotent)
# ---------------------------------------------------------
echo "--> Adding developer aliases to ~/.bashrc..."
touch ~/.bashrc
ALIAS_MARKER="# --- AUTOMATED DEV ALIASES ---"

if ! grep -q "$ALIAS_MARKER" ~/.bashrc; then
    cat << 'EOF' >> ~/.bashrc

# --- AUTOMATED DEV ALIASES ---
alias gs="git status"
alias dco="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
EOF
fi

# ---------------------------------------------------------
# 5. Housekeeping & Cache Cleans
# ---------------------------------------------------------
echo "--> Updating tldr offline database..."
tldr --update || true

echo "--> Taking out the apt trash..."
$SUDO apt-get autoremove -y > /dev/null
$SUDO apt-get clean

# ---------------------------------------------------------
# 6. Interactive Finale: Git & SSH
# ---------------------------------------------------------
echo ""
echo "=================================================="
echo "📦 ALL PACKAGES INSTALLED SUCCESSFULLY!"
echo "=================================================="
echo ""

if [ -t 0 ]; then
    read -p "🔑 Configure Git and generate a GitHub/GitLab SSH key right now? [y/N]: " setup_git

    if [[ "$setup_git" =~ ^[Yy]$ ]]; then
        read -p "Enter your full name for Git commits (e.g. Jane Doe): " git_name
        read -p "Enter your Git email address: " git_email
        
        # Set Git defaults
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main

        # Generate key instantly if one doesn't already sit there
        if [ ! -f ~/.ssh/id_ed25519 ]; then
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            ssh-keygen -t ed25519 -C "$git_email" -f ~/.ssh/id_ed25519 -N ""
            
            echo ""
            echo "------------------------------------------------------------------"
            echo "✨ NEW SSH PUBLIC KEY GENERATED:"
            cat ~/.ssh/id_ed25519.pub
            echo "------------------------------------------------------------------"
            echo "Copy the line above and paste it into GitHub -> Settings -> SSH Keys"
        else
            echo "⚠️ An Ed25519 key already exists in ~/.ssh/. Skipping generation to keep it safe."
        fi
    else
        echo "--> Skipping Git & SSH configuration."
    fi
else
    echo "--> Non-interactive shell detected. Skipping interactive Git & SSH configuration."
fi

echo ""
echo "🎉 SETUP COMPLETE! Please restart your terminal."
