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
DIM='\033[2m'
NC='\033[0m' # No Color (reset)

log_step() { echo -e "\n${BOLD}${CYAN}==>${NC}${BOLD} $1${NC}"; }
log_info() { echo -e "  ${BLUE}-->${NC} $1"; }
log_success() { echo -e "  ${GREEN}✅${NC} $1"; }
log_warning() { echo -e "  ${YELLOW}⚠️ ${NC} $1"; }
log_error() { echo -e "  ${RED}❌${NC} $1" >&2; }
log_skip() { echo -e "  ${YELLOW}-->${NC} Skipping $1."; }
log_dry() { echo -e "  ${DIM}[DRY-RUN]${NC} ${CYAN}$1${NC}"; }

# ----------------------------------------------------------
# CLI Argument Parsing
# ----------------------------------------------------------
DRY_RUN=false
MODE="interactive" # interactive | minimal | full

usage() {
    echo ""
    echo -e "${BOLD}Usage:${NC} ./setup.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo "  --dry-run     Preview what the script would install without making changes"
    echo "  --minimal     Non-interactive: install core tools only (apt packages, Docker, uv)"
    echo "  --full        Non-interactive: install everything automatically (CI-friendly)"
    echo "  --help        Show this help message and exit"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./setup.sh --dry-run --full     # Preview a full install"
    echo "  ./setup.sh --minimal            # Fast CI bootstrap"
    echo "  ./setup.sh --full               # Fully unattended install"
    echo ""
}

for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --minimal) MODE="minimal" ;;
    --full) MODE="full" ;;
    --help)
        usage
        exit 0
        ;;
    *)
        log_error "Unknown argument: $arg"
        usage
        exit 1
        ;;
    esac
done

# ----------------------------------------------------------
# Dry-run aware command wrapper
# ----------------------------------------------------------
# Usage: run_cmd "Description of action" actual command here...
run_cmd() {
    # $1 is a human-readable description used in dry-run output
    local description
    description="$1 (cmd: $2)"
    shift
    if [ "$DRY_RUN" = true ]; then
        log_dry "$description"
    else
        "$@"
    fi
}

# ----------------------------------------------------------
# Summary Table Tracking
# ----------------------------------------------------------
# Two parallel arrays: tool names and versions/status
SUMMARY_TOOLS=()
SUMMARY_STATUS=()

record_installed() {
    local tool="$1"
    local version="$2"
    SUMMARY_TOOLS+=("$tool")
    SUMMARY_STATUS+=("${version:-installed}")
}

record_skipped() {
    local tool="$1"
    SUMMARY_TOOLS+=("$tool")
    SUMMARY_STATUS+=("skipped")
}

record_already_installed() {
    local tool="$1"
    local version="$2"
    SUMMARY_TOOLS+=("$tool")
    SUMMARY_STATUS+=("already installed (${version})")
}

print_summary_table() {
    echo ""
    echo -e "${BOLD}${CYAN}=================================================${NC}"
    echo -e "${BOLD}${CYAN}  📋 Post-Install Summary Report               ${NC}"
    echo -e "${BOLD}${CYAN}=================================================${NC}"
    echo ""
    printf "  ${BOLD}%-28s %-35s${NC}\n" "Tool" "Status / Version"
    printf "  %-28s %-35s\n" "----------------------------" "-----------------------------------"
    for i in "${!SUMMARY_TOOLS[@]}"; do
        local status="${SUMMARY_STATUS[$i]}"
        if [[ "$status" == "skipped" ]]; then
            printf "  ${DIM}%-28s %-35s${NC}\n" "${SUMMARY_TOOLS[$i]}" "⏭  skipped"
        elif [[ "$status" == already* ]]; then
            printf "  ${YELLOW}%-28s %-35s${NC}\n" "${SUMMARY_TOOLS[$i]}" "✔  ${status}"
        else
            printf "  ${GREEN}%-28s %-35s${NC}\n" "${SUMMARY_TOOLS[$i]}" "✅ ${status}"
        fi
    done
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}⚠️  DRY-RUN mode: no changes were made to your system.${NC}"
        echo ""
    fi
}

# ----------------------------------------------------------
# Pre-flight: get a tool's version string (or "not installed")
# ----------------------------------------------------------
get_tool_version() {
    local cmd="$1"
    local version_flag="${2:---version}"
    if command -v "$cmd" &> /dev/null; then
        "$cmd" "$version_flag" 2>&1 | head -1
    else
        echo "not installed"
    fi
}

print_preflight_check() {
    echo ""
    echo -e "${BOLD}${BLUE}=================================================${NC}"
    echo -e "${BOLD}${BLUE}  🔍 Pre-flight Check: Current System State     ${NC}"
    echo -e "${BOLD}${BLUE}=================================================${NC}"
    echo ""
    printf "  ${BOLD}%-20s %-45s${NC}\n" "Tool" "Current Status"
    printf "  %-20s %-45s\n" "--------------------" "---------------------------------------------"

    local tools=(
        "git:git:--version"
        "gh:gh:--version"
        "docker:docker:--version"
        "uv:uv:--version"
        "fnm:fnm:--version"
        "node:node:--version"
        "rustc:rustc:--version"
        "go:go:version"
        "starship:starship:--version"
        "fzf:fzf:--version"
        "rg (ripgrep):rg:--version"
        "bat:bat:--version"
        "code (VS Code):code:--version"
    )

    for entry in "${tools[@]}"; do
        local label="${entry%%:*}"
        local rest="${entry#*:}"
        local cmd="${rest%%:*}"
        local flag="${rest#*:}"
        if command -v "$cmd" &> /dev/null; then
            local ver
            ver=$("$cmd" "$flag" 2>&1 | head -1)
            printf "  ${GREEN}%-20s${NC} %-45s\n" "$label" "✔  $ver"
        else
            printf "  ${DIM}%-20s${NC} %-45s\n" "$label" "✘  not installed"
        fi
    done
    echo ""
}

# ----------------------------------------------------------
# Mode-aware prompt helper
# Returns 0 (yes) or 1 (no)
# ----------------------------------------------------------
# Usage: prompt_user "Question text" || { ... skip block ... }
prompt_user() {
    local question="$1"
    if [ "$MODE" = "full" ]; then
        return 0 # auto-yes
    elif [ "$MODE" = "minimal" ]; then
        return 1 # auto-no
    else
        # interactive
        read -rp "$question [y/N]: " _answer
        [[ "$_answer" =~ ^[Yy]$ ]]
    fi
}

# ----------------------------------------------------------
# Banner
# ----------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}=================================================${NC}"
echo -e "${BOLD}${CYAN}  🚀 Bootstrapping Ubuntu Dev Workstation...  ${NC}"
echo -e "${BOLD}${CYAN}=================================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}⚠️  DRY-RUN mode enabled — no changes will be made.${NC}"
    echo ""
fi

if [ "$MODE" = "minimal" ]; then
    echo -e "  ${CYAN}🎯 Mode: MINIMAL — installing core tools only.${NC}"
    echo ""
elif [ "$MODE" = "full" ]; then
    echo -e "  ${CYAN}🎯 Mode: FULL — installing all tools non-interactively.${NC}"
    echo ""
fi

# ----------------------------------------------------------
# Pre-flight Check
# ----------------------------------------------------------
print_preflight_check

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
run_cmd "apt-get update" $SUDO apt-get update -y

# Configure GitHub CLI repository if not present
if ! command -v gh &> /dev/null; then
    log_info "Configuring GitHub CLI repository..."
    run_cmd "mkdir keyrings" $SUDO mkdir -p -m 755 /etc/apt/keyrings
    if [ "$DRY_RUN" = false ]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg 2> /dev/null
        $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        $SUDO apt-get update -y
    else
        log_dry "Would configure GitHub CLI APT repository"
    fi
fi

log_info "Installing core utilities & dev packages..."
run_cmd "apt-get install core packages" $SUDO apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    git curl jq htop vim lsof build-essential \
    openssh-server openssh-client tldr bash-completion unzip gh

if [ "$DRY_RUN" = false ]; then
    GIT_VER=$(get_tool_version git --version)
    GH_VER=$(get_tool_version gh --version)
    record_installed "Core utilities (apt)" "git: ${GIT_VER}, gh: ${GH_VER}"
else
    record_installed "Core utilities (apt)" "(dry-run)"
fi
log_success "Core utilities installed."

# ----------------------------------------------------------
# 1. System Tweak: Increase File Watcher Limit
# ----------------------------------------------------------
log_step "System Tweak: File Watcher Limits"
if [ -n "$SUDO" ] && [ -d "/etc/sysctl.d" ]; then
    log_info "Optimizing Linux file-watcher limits for heavy projects..."
    if [ "$DRY_RUN" = false ]; then
        echo "fs.inotify.max_user_watches=524288" | $SUDO tee /etc/sysctl.d/99-dev-tweaks.conf > /dev/null
        $SUDO sysctl --system > /dev/null || true
    else
        log_dry "Would set fs.inotify.max_user_watches=524288 in /etc/sysctl.d/99-dev-tweaks.conf"
    fi
    log_success "fs.inotify.max_user_watches set to 524288."
fi

# ----------------------------------------------------------
# 2. Docker & Docker Compose (v2)
# ----------------------------------------------------------
log_step "Docker & Docker Compose (v2)"
if ! command -v docker &> /dev/null; then
    log_info "Installing Docker Engine..."
    if [ "$DRY_RUN" = false ]; then
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

        log_info "Applying Docker CLI tab-completion rules..."
        $SUDO mkdir -p /etc/bash_completion.d
        $SUDO curl -sSL \
            https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker \
            -o /etc/bash_completion.d/docker
        DOCKER_VER=$(get_tool_version docker --version)
        record_installed "Docker" "$DOCKER_VER"
    else
        log_dry "Would install Docker Engine via https://get.docker.com"
        log_dry "Would add current user to 'docker' group"
        log_dry "Would install Docker CLI bash completion"
        record_installed "Docker" "(dry-run)"
    fi
    log_success "Docker installed successfully."
else
    DOCKER_VER=$(get_tool_version docker --version)
    record_already_installed "Docker" "$DOCKER_VER"
    log_info "Docker is already installed. Skipping."
fi

# ----------------------------------------------------------
# 3. Python Environment (Astral 'uv')
# ----------------------------------------------------------
log_step "Python Toolchain (Astral uv)"
if ! command -v uv &> /dev/null; then
    log_info "Installing 'uv' Python package manager..."
    if [ "$DRY_RUN" = false ]; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        UV_VER=$(get_tool_version uv --version)
        record_installed "uv (Python)" "$UV_VER"
    else
        log_dry "Would install 'uv' via https://astral.sh/uv/install.sh"
        record_installed "uv (Python)" "(dry-run)"
    fi
    log_success "uv installed."
else
    UV_VER=$(get_tool_version uv --version)
    record_already_installed "uv (Python)" "$UV_VER"
    log_info "uv is already installed. Skipping."
fi

# Configure uv shell autocompletion (safe / idempotent)
log_info "Configuring uv shell autocompletion..."
UV_MARKER="# --- AUTOMATED UV COMPLETION ---"
for profile in "${PROFILES[@]}"; do
    if ! grep -q "$UV_MARKER" "$profile"; then
        if [[ "$profile" == *".zshrc" ]]; then
            shell_type="zsh"
        else
            shell_type="bash"
        fi

        if [ "$DRY_RUN" = false ]; then
            cat << EOF >> "$profile"

# --- AUTOMATED UV COMPLETION ---
if command -v uv &>/dev/null; then
    eval "\$(uv generate-shell-completion ${shell_type})"
elif [ -f "\$HOME/.local/bin/uv" ]; then
    eval "\$("\$HOME/.local/bin/uv" generate-shell-completion ${shell_type})"
fi
EOF
        else
            log_dry "Would append uv completion block to $profile"
        fi
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
        if [ "$DRY_RUN" = false ]; then
            cat << 'EOF' >> "$profile"

# --- AUTOMATED DEV ALIASES ---
alias gs="git status"
alias dco="docker compose"
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
EOF
        else
            log_dry "Would append dev aliases block to $profile"
        fi
    fi
done
log_success "Aliases registered."

# ----------------------------------------------------------
# 5. Housekeeping & Cache Cleanup
# ----------------------------------------------------------
log_step "Housekeeping"
log_info "Updating tldr offline database..."
if [ "$DRY_RUN" = false ]; then
    tldr --update || true
else
    log_dry "Would run: tldr --update"
fi

log_info "Cleaning up apt cache..."
run_cmd "apt-get autoremove" $SUDO apt-get autoremove -y > /dev/null
run_cmd "apt-get clean" $SUDO apt-get clean

# ----------------------------------------------------------
# 6. Interactive / Mode-based Configuration
#    (Git, Node.js, Rust, Go, Starship, CLI tools, IDEs)
# ----------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}=================================================${NC}"
echo -e "${BOLD}${GREEN}  📦 CORE SETUP COMPLETE! Moving to optional... ${NC}"
echo -e "${BOLD}${GREEN}=================================================${NC}"
echo ""

# Only run optional installs in interactive mode or --full mode
if [ -t 0 ] || [ "$MODE" = "full" ] || [ "$MODE" = "minimal" ]; then

    # --- Git & SSH Setup ---
    log_step "Git & SSH Configuration"
    if prompt_user "🔑 Configure Git and generate a GitHub/GitLab SSH key right now?"; then
        if [ "$MODE" = "interactive" ]; then
            read -rp "   Enter your full name for Git commits (e.g. Jane Doe): " git_name
            read -rp "   Enter your Git email address: " git_email
        else
            git_name="Dev User"
            git_email="dev@example.com"
            log_info "Non-interactive mode: using placeholder Git identity (update later with git config --global)."
        fi

        if [ "$DRY_RUN" = false ]; then
            git config --global user.name "$git_name"
            git config --global user.email "$git_email"
            git config --global init.defaultBranch main

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
            log_dry "Would run: git config --global user.name '$git_name'"
            log_dry "Would run: git config --global user.email '$git_email'"
            log_dry "Would run: git config --global init.defaultBranch main"
            log_dry "Would generate SSH key: ~/.ssh/id_ed25519 (if not exists)"
        fi
        record_installed "Git config & SSH key" "$(get_tool_version git --version)"
    else
        record_skipped "Git config & SSH key"
        log_skip "Git & SSH configuration"
    fi

    # --- Node.js Setup (via fnm) ---
    log_step "Node.js (via FNM)"
    if prompt_user "🟨 Do you want to install Node.js (via FNM - Fast Node Manager)?"; then
        if ! command -v fnm &> /dev/null; then
            log_info "Installing fnm (Fast Node Manager)..."
            if [ "$DRY_RUN" = false ]; then
                curl -fsSL https://fnm.vercel.app/install | bash
                export PATH="$HOME/.local/share/fnm:$PATH"
                eval "$(fnm env --use-on-cd)"
            else
                log_dry "Would install fnm via https://fnm.vercel.app/install"
            fi
        else
            log_info "fnm is already installed."
        fi

        if ! command -v node &> /dev/null; then
            log_info "Installing Node.js LTS..."
            if [ "$DRY_RUN" = false ]; then
                fnm install --lts
                fnm default "$(fnm current)"
                NODE_VER=$(node -v 2> /dev/null || echo "installed")
                log_success "Node.js $NODE_VER installed."
                record_installed "Node.js (fnm)" "$NODE_VER"
            else
                log_dry "Would run: fnm install --lts"
                record_installed "Node.js (fnm)" "(dry-run)"
            fi
        else
            NODE_VER=$(node -v 2> /dev/null || echo "")
            record_already_installed "Node.js (fnm)" "$NODE_VER"
            log_info "Node.js is already installed: $(node -v)"
        fi
    else
        record_skipped "Node.js (fnm)"
        log_skip "Node.js installation"
    fi

    # --- Rust Toolchain (via rustup) ---
    log_step "Rust Toolchain"
    if prompt_user "🦀 Do you want to install Rust (via rustup)?"; then
        if ! command -v rustc &> /dev/null; then
            log_info "Installing Rust toolchain via rustup..."
            if [ "$DRY_RUN" = false ]; then
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

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
                record_installed "Rust (rustup)" "$(rustc --version 2> /dev/null || echo 'installed')"
            else
                log_dry "Would install Rust via https://sh.rustup.rs"
                log_dry "Would append ~/.cargo/env source block to shell profiles"
                record_installed "Rust (rustup)" "(dry-run)"
            fi
            log_success "Rust installed. Run 'source ~/.cargo/env' to use it now."
        else
            RUST_VER=$(get_tool_version rustc --version)
            record_already_installed "Rust (rustup)" "$RUST_VER"
            log_info "Rust is already installed: $(rustc --version)"
        fi
    else
        record_skipped "Rust (rustup)"
        log_skip "Rust installation"
    fi

    # --- Go Toolchain ---
    log_step "Go Toolchain"
    if prompt_user "🐹 Do you want to install Go (Golang)?"; then
        if ! command -v go &> /dev/null; then
            log_info "Fetching latest Go version..."
            if [ "$DRY_RUN" = false ]; then
                GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
                GO_ARCHIVE="${GO_VERSION}.linux-amd64.tar.gz"
                log_info "Downloading ${GO_VERSION}..."
                curl -fsSL "https://go.dev/dl/${GO_ARCHIVE}" -o "/tmp/${GO_ARCHIVE}"
                $SUDO rm -rf /usr/local/go
                $SUDO tar -C /usr/local -xzf "/tmp/${GO_ARCHIVE}"
                rm -f "/tmp/${GO_ARCHIVE}"

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
                record_installed "Go (golang)" "$GO_VERSION"
            else
                log_dry "Would fetch latest Go version from https://go.dev/VERSION"
                log_dry "Would download and extract Go to /usr/local/go"
                log_dry "Would append Go PATH block to shell profiles"
                record_installed "Go (golang)" "(dry-run)"
            fi
        else
            GO_VER=$(get_tool_version go version)
            record_already_installed "Go (golang)" "$GO_VER"
            log_info "Go is already installed: $(go version)"
        fi
    else
        record_skipped "Go (golang)"
        log_skip "Go installation"
    fi

    # --- Starship Prompt ---
    log_step "Starship Shell Prompt"
    if prompt_user "🚀 Do you want to install Starship (modern cross-shell prompt)?"; then
        if ! command -v starship &> /dev/null; then
            log_info "Installing Starship prompt..."
            if [ "$DRY_RUN" = false ]; then
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
            else
                log_dry "Would install Starship via https://starship.rs/install.sh"
            fi
        else
            log_info "Starship is already installed."
        fi

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
                if [ "$DRY_RUN" = false ]; then
                    cat << EOF >> "$profile"

# --- AUTOMATED STARSHIP INIT ---
${init_cmd}
EOF
                else
                    log_dry "Would append Starship init block to $profile"
                fi
            fi
        done
        if [ "$DRY_RUN" = false ]; then
            STARSHIP_VER=$(get_tool_version starship --version)
            record_installed "Starship prompt" "$STARSHIP_VER"
        else
            record_installed "Starship prompt" "(dry-run)"
        fi
        log_success "Starship configured for all active shell profiles."
    else
        record_skipped "Starship prompt"
        log_skip "Starship installation"
    fi

    # --- Modern CLI Utilities (fzf, ripgrep, bat) ---
    log_step "Modern CLI Utilities"
    if prompt_user "🛠️  Do you want to install modern CLI utilities (fzf, ripgrep, bat)?"; then
        log_info "Installing fzf, ripgrep, bat..."
        # NOTE: On Ubuntu, 'bat' package binary is named 'batcat' to avoid a naming conflict
        run_cmd "apt-get install fzf ripgrep bat" $SUDO apt-get install -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            fzf ripgrep bat

        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$HOME/.local/bin"
            if [ -f /usr/bin/batcat ]; then
                ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
                log_info "Created symlink: bat -> /usr/bin/batcat"
            fi
        else
            log_dry "Would create symlink: ~/.local/bin/bat -> /usr/bin/batcat"
        fi

        PATH_MARKER="# --- AUTOMATED LOCAL BIN PATH ---"
        for profile in "${PROFILES[@]}"; do
            if ! grep -q "$PATH_MARKER" "$profile"; then
                if [ "$DRY_RUN" = false ]; then
                    cat << 'EOF' >> "$profile"

# --- AUTOMATED LOCAL BIN PATH ---
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
EOF
                else
                    log_dry "Would append ~/.local/bin PATH block to $profile"
                fi
            fi
        done

        FZF_VER=$(get_tool_version fzf --version)
        RG_VER=$(get_tool_version rg --version)
        record_installed "fzf / ripgrep / bat" "fzf: ${FZF_VER}, rg: ${RG_VER}"
        log_success "fzf, ripgrep, and bat are ready to use."
    else
        record_skipped "fzf / ripgrep / bat"
        log_skip "modern CLI utilities"
    fi

    # --- GUI Desktop Applications (VS Code, PyCharm) ---
    if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
        log_step "Desktop IDEs (GUI-only)"

        if prompt_user "🖥️  GUI Desktop detected. Do you want to install VS Code?"; then
            if ! command -v code &> /dev/null; then
                log_info "Installing VS Code..."
                if [ "$DRY_RUN" = false ]; then
                    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
                    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null
                    $SUDO apt-get update -y
                    $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" code
                    CODE_VER=$(get_tool_version code --version)
                    record_installed "VS Code" "$CODE_VER"
                else
                    log_dry "Would install VS Code from packages.microsoft.com"
                    record_installed "VS Code" "(dry-run)"
                fi
                log_success "VS Code installed."
            else
                CODE_VER=$(get_tool_version code --version)
                record_already_installed "VS Code" "$CODE_VER"
                log_info "VS Code is already installed."
            fi
        else
            record_skipped "VS Code"
            log_skip "VS Code"
        fi

        echo ""
        if prompt_user "🐍 Do you want to install PyCharm Community Edition?"; then
            if ! command -v pycharm-community &> /dev/null; then
                log_info "Installing PyCharm Community..."
                if [ "$DRY_RUN" = false ]; then
                    $SUDO snap install pycharm-community --classic
                    record_installed "PyCharm Community" "snap install"
                else
                    log_dry "Would run: snap install pycharm-community --classic"
                    record_installed "PyCharm Community" "(dry-run)"
                fi
                log_success "PyCharm Community installed."
            else
                record_already_installed "PyCharm Community" "installed"
                log_info "PyCharm Community is already installed."
            fi
        else
            record_skipped "PyCharm Community"
            log_skip "PyCharm Community"
        fi
    fi

else
    log_warning "Non-interactive shell detected. Skipping optional configuration."
    echo -e "  ${CYAN}💡 Tip:${NC} Use --full or --minimal flags for non-interactive installs:"
    echo "     ./setup.sh --full"
    echo "  Or use process substitution for interactive mode:"
    echo "     bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh)"
fi

# ----------------------------------------------------------
# Post-Install Summary Report
# ----------------------------------------------------------
print_summary_table

echo -e "${BOLD}${GREEN}🎉 SETUP COMPLETE! Please restart your terminal (or run: source ~/.bashrc)${NC}"
echo ""
