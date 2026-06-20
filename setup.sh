#!/usr/bin/env bash
set -e

# ==========================================================
# Ubuntu Dev Setup - Bootstrap Script
# https://github.com/Harshidpatel12/ubuntu-dev-setup
# ==========================================================

# Prevent interactive prompts (like service restart dialogs) during package installs
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l

echo "=================================================="
echo "🚀 Bootstrapping Ubuntu Dev Workstation..."
echo "=================================================="
echo ""

# ----------------------------------------------------------
# Detect if running as root (Docker) or normal user (Host)
# ----------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Ensure shell profiles exist and are identified
PROFILES=("$HOME/.bashrc")
if [ -f "$HOME/.zshrc" ] || command -v zsh &> /dev/null; then
    touch "$HOME/.zshrc"
    PROFILES+=("$HOME/.zshrc")
fi

# ----------------------------------------------------------
# 0. System Package Index & Core Utilities
# ----------------------------------------------------------
echo "--> Updating system package index..."
$SUDO apt-get update -y

# Configure GitHub CLI repository if not present
if ! command -v gh &> /dev/null; then
    echo "--> Configuring GitHub CLI repository..."
    $SUDO mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2> /dev/null
    $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    $SUDO apt-get update -y
fi

echo "--> Installing core utilities & dev packages..."
$SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
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
    bash-completion \
    gh

# ----------------------------------------------------------
# 1. System Tweak: Increase File Watcher Limit
# ----------------------------------------------------------
if [ -n "$SUDO" ] && [ -d "/etc/sysctl.d" ]; then
    echo "--> Optimizing Linux file-watcher limits for heavy projects..."
    echo "fs.inotify.max_user_watches=524288" | $SUDO tee /etc/sysctl.d/99-dev-tweaks.conf > /dev/null
    $SUDO sysctl --system > /dev/null || true
fi

# ----------------------------------------------------------
# 2. Docker & Docker Compose (v2)
# ----------------------------------------------------------
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
        echo "--> Granted '$USER' permission to run Docker without sudo."
    fi

    # Apply Docker CLI tab-completion only on fresh install
    echo "--> Applying Docker CLI tab-completion rules..."
    $SUDO mkdir -p /etc/bash_completion.d
    $SUDO curl -sSL \
        https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker \
        -o /etc/bash_completion.d/docker
else
    echo "--> Docker is already installed. Skipping."
fi

# ----------------------------------------------------------
# 3. Python Environment (Astral 'uv')
# ----------------------------------------------------------
if ! command -v uv &> /dev/null; then
    echo "--> Installing 'uv' Python package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "--> 'uv' is already installed. Skipping."
fi

# Configure uv shell autocompletion (safe / idempotent)
# NOTE: uv installs to ~/.local/bin/uv on first run, so PATH may not
# be updated yet in this session. The elif fallback handles that case.
echo "--> Configuring 'uv' shell autocompletion..."
UV_MARKER="# --- AUTOMATED UV COMPLETION ---"
for profile in "${PROFILES[@]}"; do
    if ! grep -q "$UV_MARKER" "$profile"; then
        if [[ "$profile" == *".zshrc" ]]; then
            shell_type="zsh"
        else
            shell_type="bash"
        fi

        cat << EOF >> "$profile"

# --- AUTOMATED UV COMPLETION ---
if command -v uv &> /dev/null; then
    eval "\$(uv generate-shell-completion ${shell_type})"
elif [ -f "\$HOME/.local/bin/uv" ]; then
    eval "\$(\"\$HOME/.local/bin/uv\" generate-shell-completion ${shell_type})"
fi
EOF
    fi
done

# ----------------------------------------------------------
# 4. Inject Dev Aliases (Safe / Idempotent)
# ----------------------------------------------------------
echo "--> Adding developer aliases to shell profiles..."
ALIAS_MARKER="# --- AUTOMATED DEV ALIASES ---"
for profile in "${PROFILES[@]}"; do
    if ! grep -q "$ALIAS_MARKER" "$profile"; then
        cat << 'EOF' >> "$profile"

# --- AUTOMATED DEV ALIASES ---
alias gs="git status"
alias dco="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
EOF
    fi
done

# ----------------------------------------------------------
# 5. Housekeeping & Cache Cleanup
# ----------------------------------------------------------
echo "--> Updating tldr offline database..."
tldr --update || true

echo "--> Cleaning up apt cache..."
$SUDO apt-get autoremove -y > /dev/null
$SUDO apt-get clean

# ----------------------------------------------------------
# 6. Interactive Configuration (Git, Node.js, CLI tools)
# ----------------------------------------------------------
echo ""
echo "=================================================="
echo "📦 ALL PACKAGES INSTALLED SUCCESSFULLY!"
echo "=================================================="
echo ""

if [ -t 0 ]; then

    # --- Git & SSH Setup ---
    read -rp "🔑 Configure Git and generate a GitHub/GitLab SSH key right now? [y/N]: " setup_git

    if [[ "$setup_git" =~ ^[Yy]$ ]]; then
        read -rp "Enter your full name for Git commits (e.g. Jane Doe): " git_name
        read -rp "Enter your Git email address: " git_email

        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main

        # Generate key only if one doesn't already exist
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
            echo "⚠️  An Ed25519 key already exists at ~/.ssh/id_ed25519. Skipping to keep it safe."
        fi
    else
        echo "--> Skipping Git & SSH configuration."
    fi

    # --- Node.js Setup (via fnm) ---
    echo ""
    read -rp "🟨 Do you want to install Node.js (via FNM - Fast Node Manager)? [y/N]: " setup_node

    if [[ "$setup_node" =~ ^[Yy]$ ]]; then
        if ! command -v fnm &> /dev/null; then
            echo "--> Installing fnm (Fast Node Manager)..."
            curl -fsSL https://fnm.vercel.app/install | bash

            # Source fnm into the current session so we can use it immediately
            export PATH="$HOME/.local/share/fnm:$PATH"
            eval "$(fnm env --use-on-cd)"
        else
            echo "--> 'fnm' is already installed."
        fi

        # Install Node.js LTS if node is not yet available
        if ! command -v node &> /dev/null; then
            echo "--> Installing Node.js LTS..."
            fnm install --lts
            # Use the version just installed as the default
            fnm default "$(fnm current)"
        else
            echo "--> Node.js is already installed: $(node -v)"
        fi
    else
        echo "--> Skipping Node.js installation."
    fi

    # --- Modern CLI Utilities (fzf, ripgrep, bat) ---
    echo ""
    read -rp "🚀 Do you want to install modern CLI utilities (fzf, ripgrep, bat)? [y/N]: " setup_cli_utils

    if [[ "$setup_cli_utils" =~ ^[Yy]$ ]]; then
        echo "--> Installing fzf, ripgrep, batcat..."
        # NOTE: On Ubuntu, 'bat' is packaged as 'batcat' to avoid a naming conflict
        $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" fzf ripgrep batcat

        # Create a 'bat' symlink so it can be called as 'bat' instead of 'batcat'
        mkdir -p "$HOME/.local/bin"
        if [ -f /usr/bin/batcat ]; then
            ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
            echo "--> Created symlink: bat -> /usr/bin/batcat"
        fi

        # Ensure ~/.local/bin is on PATH in profiles (idempotent)
        PATH_MARKER="# --- AUTOMATED LOCAL BIN PATH ---"
        for profile in "${PROFILES[@]}"; do
            if ! grep -q "$PATH_MARKER" "$profile"; then
                cat << 'EOF' >> "$profile"

# --- AUTOMATED LOCAL BIN PATH ---
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
            fi
        done

        echo "--> fzf, ripgrep, and bat are ready to use."
    else
        echo "--> Skipping modern CLI utilities."
    fi

    # --- GUI Desktop Applications (VS Code, PyCharm) ---
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        echo ""
        read -rp "🖥️  GUI Desktop detected. Do you want to install VS Code? [y/N]: " setup_vscode
        if [[ "$setup_vscode" =~ ^[Yy]$ ]]; then
            if ! command -v code &> /dev/null; then
                echo "--> Installing VS Code..."
                # Import Microsoft GPG key
                curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
                # Add Microsoft VS Code repository
                echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null
                $SUDO apt-get update -y
                $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" code
            else
                echo "--> VS Code is already installed."
            fi
        else
            echo "--> Skipping VS Code installation."
        fi

        echo ""
        read -rp "🐍 Do you want to install PyCharm Community Edition? [y/N]: " setup_pycharm
        if [[ "$setup_pycharm" =~ ^[Yy]$ ]]; then
            if ! command -v pycharm-community &> /dev/null; then
                echo "--> Installing PyCharm Community..."
                $SUDO snap install pycharm-community --classic
            else
                echo "--> PyCharm Community is already installed."
            fi
        else
            echo "--> Skipping PyCharm Community installation."
        fi
    fi

else
    echo "--> Non-interactive shell detected. Skipping interactive configuration."
    echo "💡 Note: To run the interactive setup (Git, Node, CLI tools, IDEs) directly,"
    echo "   execute the script using process substitution instead of piping:"
    echo "   bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh)"
fi

echo ""
echo "🎉 SETUP COMPLETE! Please restart your terminal (or run: source ~/.bashrc)"
echo ""
