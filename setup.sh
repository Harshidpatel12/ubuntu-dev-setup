#!/usr/bin/env bash
set -e

# ==========================================================
# Ubuntu Dev Setup - Bootstrap Script
# https://github.com/Harshidpatel12/ubuntu-dev-setup
# ==========================================================

# Prevent interactive prompts (like service restart dialogs) during package installs
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l

# ----------------------------------------------------------
# Color & Logging Helpers
# ----------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color (reset)

log_step() { echo -e "\n${BOLD}${CYAN}==>${NC}${BOLD} $1${NC}"; }
log_info() { echo -e "  ${BLUE}-->${NC} $1"; }
log_success() { echo -e "  ${GREEN}✅${NC} $1"; }
log_warning() { echo -e "  ${YELLOW}⚠️ ${NC} $1"; }
log_error() { echo -e "  ${RED}❌${NC} $1" >&2; }
log_skip() { echo -e "  ${YELLOW}-->${NC} Skipping $1."; }

# ----------------------------------------------------------
# Banner
# ----------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}=================================================${NC}"
echo -e "${BOLD}${CYAN}  🚀 Bootstrapping Ubuntu Dev Workstation...  ${NC}"
echo -e "${BOLD}${CYAN}=================================================${NC}"
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
log_step "System Package Index & Core Utilities"
log_info "Updating system package index..."
$SUDO apt-get update -y

# Configure GitHub CLI repository if not present
if ! command -v gh &> /dev/null; then
    log_info "Configuring GitHub CLI repository..."
    $SUDO mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2> /dev/null
    $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    $SUDO apt-get update -y
fi

log_info "Installing core utilities & dev packages..."
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
log_success "Core utilities installed."

# ----------------------------------------------------------
# 1. System Tweak: Increase File Watcher Limit
# ----------------------------------------------------------
log_step "System Tweak: File Watcher Limits"
if [ -n "$SUDO" ] && [ -d "/etc/sysctl.d" ]; then
    log_info "Optimizing Linux file-watcher limits for heavy projects..."
    echo "fs.inotify.max_user_watches=524288" | $SUDO tee /etc/sysctl.d/99-dev-tweaks.conf > /dev/null
    $SUDO sysctl --system > /dev/null || true
    log_success "fs.inotify.max_user_watches set to 524288."
fi

# ----------------------------------------------------------
# 2. Docker & Docker Compose (v2)
# ----------------------------------------------------------
log_step "Docker & Docker Compose (v2)"
if ! command -v docker &> /dev/null; then
    log_info "Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    if $SUDO sh get-docker.sh; then
        rm -f get-docker.sh
    else
        rm -f get-docker.sh
        log_error "Docker installation failed!"
        exit 1
    fi

    if [ -n "$SUDO" ]; then
        $SUDO usermod -aG docker "$USER"
        log_info "Granted '$USER' permission to run Docker without sudo."
    fi

    # Apply Docker CLI tab-completion only on fresh install
    log_info "Applying Docker CLI tab-completion rules..."
    $SUDO mkdir -p /etc/bash_completion.d
    $SUDO curl -sSL \
        https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker \
        -o /etc/bash_completion.d/docker
    log_success "Docker installed successfully."
else
    log_info "Docker is already installed. Skipping."
fi

# ----------------------------------------------------------
# 3. Python Environment (Astral 'uv')
# ----------------------------------------------------------
log_step "Python Toolchain (Astral uv)"
if ! command -v uv &> /dev/null; then
    log_info "Installing 'uv' Python package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_success "uv installed."
else
    log_info "uv is already installed. Skipping."
fi

# Configure uv shell autocompletion (safe / idempotent)
# NOTE: uv installs to ~/.local/bin/uv on first run, so PATH may not
# be updated yet in this session. The elif fallback handles that case.
log_info "Configuring uv shell autocompletion..."
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
    eval "\$("\$HOME/.local/bin/uv" generate-shell-completion ${shell_type})"
fi
EOF
    fi
done

# ----------------------------------------------------------
# 4. Inject Dev Aliases (Safe / Idempotent)
# ----------------------------------------------------------
log_step "Developer Shell Aliases"
log_info "Adding developer aliases to shell profiles..."
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
log_success "Aliases registered."

# ----------------------------------------------------------
# 5. Housekeeping & Cache Cleanup
# ----------------------------------------------------------
log_step "Housekeeping"
log_info "Updating tldr offline database..."
tldr --update || true

log_info "Cleaning up apt cache..."
$SUDO apt-get autoremove -y > /dev/null
$SUDO apt-get clean

# ----------------------------------------------------------
# 6. Interactive Configuration (Git, Node.js, Rust, Go, Starship, CLI tools, IDEs)
# ----------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}=================================================${NC}"
echo -e "${BOLD}${GREEN}  📦 ALL PACKAGES INSTALLED SUCCESSFULLY!       ${NC}"
echo -e "${BOLD}${GREEN}=================================================${NC}"
echo ""

if [ -t 0 ]; then

    # --- Git & SSH Setup ---
    log_step "Git & SSH Configuration"
    read -rp "🔑 Configure Git and generate a GitHub/GitLab SSH key right now? [y/N]: " setup_git

    if [[ "$setup_git" =~ ^[Yy]$ ]]; then
        read -rp "   Enter your full name for Git commits (e.g. Jane Doe): " git_name
        read -rp "   Enter your Git email address: " git_email

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
            echo -e "${BOLD}${GREEN}✨ NEW SSH PUBLIC KEY GENERATED:${NC}"
            cat ~/.ssh/id_ed25519.pub
            echo "------------------------------------------------------------------"
            log_info "Copy the key above and paste it into GitHub -> Settings -> SSH Keys"
        else
            log_warning "An Ed25519 key already exists at ~/.ssh/id_ed25519. Skipping to keep it safe."
        fi
    else
        log_skip "Git & SSH configuration"
    fi

    # --- Node.js Setup (via fnm) ---
    log_step "Node.js (via FNM)"
    read -rp "🟨 Do you want to install Node.js (via FNM - Fast Node Manager)? [y/N]: " setup_node

    if [[ "$setup_node" =~ ^[Yy]$ ]]; then
        if ! command -v fnm &> /dev/null; then
            log_info "Installing fnm (Fast Node Manager)..."
            curl -fsSL https://fnm.vercel.app/install | bash

            # Source fnm into the current session so we can use it immediately
            export PATH="$HOME/.local/share/fnm:$PATH"
            eval "$(fnm env --use-on-cd)"
        else
            log_info "fnm is already installed."
        fi

        # Install Node.js LTS if node is not yet available
        if ! command -v node &> /dev/null; then
            log_info "Installing Node.js LTS..."
            fnm install --lts
            # Use the version just installed as the default
            fnm default "$(fnm current)"
            log_success "Node.js $(node -v) installed."
        else
            log_info "Node.js is already installed: $(node -v)"
        fi
    else
        log_skip "Node.js installation"
    fi

    # --- Rust Toolchain (via rustup) ---
    log_step "Rust Toolchain"
    read -rp "🦀 Do you want to install Rust (via rustup)? [y/N]: " setup_rust

    if [[ "$setup_rust" =~ ^[Yy]$ ]]; then
        if ! command -v rustc &> /dev/null; then
            log_info "Installing Rust toolchain via rustup..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

            # Add Rust to PATH for the current session and all shell profiles
            RUST_MARKER="# --- AUTOMATED RUST PATH ---"
            for profile in "${PROFILES[@]}"; do
                if ! grep -q "$RUST_MARKER" "$profile"; then
                    cat << 'EOF' >> "$profile"

# --- AUTOMATED RUST PATH ---
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi
EOF
                fi
            done
            log_success "Rust installed. Run 'source ~/.cargo/env' to use it now."
        else
            log_info "Rust is already installed: $(rustc --version)"
        fi
    else
        log_skip "Rust installation"
    fi

    # --- Go Toolchain ---
    log_step "Go Toolchain"
    read -rp "🐹 Do you want to install Go (Golang)? [y/N]: " setup_go

    if [[ "$setup_go" =~ ^[Yy]$ ]]; then
        if ! command -v go &> /dev/null; then
            log_info "Fetching latest Go version..."
            GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
            GO_ARCHIVE="${GO_VERSION}.linux-amd64.tar.gz"
            log_info "Downloading ${GO_VERSION}..."
            curl -fsSL "https://go.dev/dl/${GO_ARCHIVE}" -o "/tmp/${GO_ARCHIVE}"
            $SUDO rm -rf /usr/local/go
            $SUDO tar -C /usr/local -xzf "/tmp/${GO_ARCHIVE}"
            rm -f "/tmp/${GO_ARCHIVE}"

            # Add Go to PATH in profiles
            GO_MARKER="# --- AUTOMATED GO PATH ---"
            for profile in "${PROFILES[@]}"; do
                if ! grep -q "$GO_MARKER" "$profile"; then
                    cat << 'EOF' >> "$profile"

# --- AUTOMATED GO PATH ---
if [ -d "/usr/local/go/bin" ]; then
    export PATH="$PATH:/usr/local/go/bin"
fi
if [ -d "$HOME/go/bin" ]; then
    export PATH="$PATH:$HOME/go/bin"
fi
EOF
                fi
            done
            log_success "Go ${GO_VERSION} installed."
        else
            log_info "Go is already installed: $(go version)"
        fi
    else
        log_skip "Go installation"
    fi

    # --- Starship Prompt ---
    log_step "Starship Shell Prompt"
    read -rp "🚀 Do you want to install Starship (modern cross-shell prompt)? [y/N]: " setup_starship

    if [[ "$setup_starship" =~ ^[Yy]$ ]]; then
        if ! command -v starship &> /dev/null; then
            log_info "Installing Starship prompt..."
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
        else
            log_info "Starship is already installed."
        fi

        # Register Starship in all detected shell profiles
        STARSHIP_MARKER="# --- AUTOMATED STARSHIP INIT ---"
        for profile in "${PROFILES[@]}"; do
            if ! grep -q "$STARSHIP_MARKER" "$profile"; then
                if [[ "$profile" == *".zshrc" ]]; then
                    # shellcheck disable=SC2016
                    init_cmd='eval "$(starship init zsh)"'
                else
                    # shellcheck disable=SC2016
                    init_cmd='eval "$(starship init bash)"'
                fi
                cat << EOF >> "$profile"

# --- AUTOMATED STARSHIP INIT ---
${init_cmd}
EOF
            fi
        done
        log_success "Starship configured for all active shell profiles."
    else
        log_skip "Starship installation"
    fi

    # --- Modern CLI Utilities (fzf, ripgrep, bat) ---
    log_step "Modern CLI Utilities"
    read -rp "🛠️  Do you want to install modern CLI utilities (fzf, ripgrep, bat)? [y/N]: " setup_cli_utils

    if [[ "$setup_cli_utils" =~ ^[Yy]$ ]]; then
        log_info "Installing fzf, ripgrep, bat..."
        # NOTE: On Ubuntu, the 'bat' package is installed but the binary is named 'batcat' to avoid a naming conflict
        $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" fzf ripgrep bat

        # Create a 'bat' symlink so it can be called as 'bat' instead of 'batcat'
        mkdir -p "$HOME/.local/bin"
        if [ -f /usr/bin/batcat ]; then
            ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
            log_info "Created symlink: bat -> /usr/bin/batcat"
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

        log_success "fzf, ripgrep, and bat are ready to use."
    else
        log_skip "modern CLI utilities"
    fi

    # --- GUI Desktop Applications (VS Code, PyCharm) ---
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        log_step "Desktop IDEs (GUI-only)"

        read -rp "🖥️  GUI Desktop detected. Do you want to install VS Code? [y/N]: " setup_vscode
        if [[ "$setup_vscode" =~ ^[Yy]$ ]]; then
            if ! command -v code &> /dev/null; then
                log_info "Installing VS Code..."
                # Import Microsoft GPG key
                curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
                # Add Microsoft VS Code repository
                echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null
                $SUDO apt-get update -y
                $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" code
                log_success "VS Code installed."
            else
                log_info "VS Code is already installed."
            fi
        else
            log_skip "VS Code"
        fi

        echo ""
        read -rp "🐍 Do you want to install PyCharm Community Edition? [y/N]: " setup_pycharm
        if [[ "$setup_pycharm" =~ ^[Yy]$ ]]; then
            if ! command -v pycharm-community &> /dev/null; then
                log_info "Installing PyCharm Community..."
                $SUDO snap install pycharm-community --classic
                log_success "PyCharm Community installed."
            else
                log_info "PyCharm Community is already installed."
            fi
        else
            log_skip "PyCharm Community"
        fi
    fi

else
    log_warning "Non-interactive shell detected. Skipping interactive configuration."
    echo -e "  ${CYAN}💡 Tip:${NC} To run the full interactive setup (Git, Node, Rust, Go, IDEs...),"
    echo "     use process substitution instead of piping:"
    echo "     bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh)"
fi

echo ""
echo -e "${BOLD}${GREEN}🎉 SETUP COMPLETE! Please restart your terminal (or run: source ~/.bashrc)${NC}"
echo ""
