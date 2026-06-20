# 🚀 ubuntu-dev-setup

[![OS](https://img.shields.io/badge/OS-Ubuntu-orange?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/shell-bash-blue?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Lint Setup Script](https://github.com/Harshidpatel12/ubuntu-dev-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/Harshidpatel12/ubuntu-dev-setup/actions/workflows/lint.yml)
[![Test Setup Script](https://github.com/Harshidpatel12/ubuntu-dev-setup/actions/workflows/test.yml/badge.svg)](https://github.com/Harshidpatel12/ubuntu-dev-setup/actions/workflows/test.yml)

An automated, developer-focused bootstrap script to configure a fresh Ubuntu workstation into a high-productivity development environment in minutes.

Whether you are setting up a local machine, a fresh VM, or a remote server, **ubuntu-dev-setup** installs core utilities, configures containerization, sets up optimized system limits, configures rapid Python package tooling, registers helpful aliases, and sets up Git/SSH credentials securely.

---

## ✨ Features

- 📦 **Core Utilities & Toolchains**: Installs essential development packages (`git`, `gh`, `curl`, `jq`, `htop`, `vim`, `lsof`, `build-essential`, `openssh`).
- 🐳 **Docker Ecosystem**: Installs Docker Engine & Docker Compose (v2) from official Docker repositories, configures non-root access, and configures Docker CLI shell auto-completions.
- ⚡ **Lightning Fast Python**: Installs Astral's [`uv`](https://github.com/astral-sh/uv) (fast Python toolchain manager) and automatically configures shell autocompletions for Bash and Zsh.
- 🟨 **Interactive Node.js Setup (Optional)**: Prompts to install Fast Node Manager (`fnm`) and Node.js LTS, keeping your JavaScript setup modern and switchable.
- 🦀 **Rust Toolchain (Optional)**: Installs `rustup` with the stable toolchain and automatically configures `~/.cargo/env` in all shell profiles.
- 🐹 **Go Toolchain (Optional)**: Downloads and installs the latest official Go release from `go.dev` into `/usr/local/go` and injects `$GOPATH/bin` into your shell PATH.
- 🚀 **Starship Prompt (Optional)**: Installs [Starship](https://starship.rs) — a blazing-fast, infinitely customizable cross-shell prompt — and registers its init hook for Bash and Zsh.
- 🛠️ **Modern CLI Power-ups (Optional)**: Prompts to install high-productivity command line utilities: `fzf` (fuzzy finder), `ripgrep` (search), and `bat` (enhanced cat with syntax highlighting).
- 🖥️ **Desktop IDEs (Optional / GUI-only)**: Safely detects a graphical desktop environment and offers to install **VS Code** (native Microsoft APT package) and **PyCharm Community** (classic Snap package).
- ⚙️ **Performance Tweaks**: Optimizes Linux file-watcher limits (`fs.inotify.max_user_watches`) to ensure smooth performance in heavy IDEs (like VS Code, IntelliJ, etc.).
- 🎨 **Colorized Output**: Every stage uses ANSI color-coded log helpers (`log_step`, `log_success`, `log_warning`, `log_error`) so you can follow progress at a glance.
- 💻 **Productive Environment**: Registers pre-configured, helpful shell aliases (e.g., `gs`, `dco`, `dps`) and PATH settings to **both Bash and Zsh** (via `~/.bashrc` and `~/.zshrc`).
- 🔑 **Interactive Identity Setup**: Guides you through configuring Git global settings and generates modern `Ed25519` SSH keys for GitHub/GitLab without overwriting existing keys.
- 🐳 **Container & Host Aware**: Automatically detects if it is running inside a Docker container (where root is the default) or on a host machine, adapting permissions and execution styles accordingly.
- 🔍 **Pre-flight Idempotency Check**: Scans and displays current versions of all known tools before doing anything, so you know exactly what will change.
- 📋 **Post-install Summary Report**: Prints a clean formatted table at the end showing every tool's status (newly installed with version, already installed, or skipped).
- 🧪 **`--dry-run` Mode**: Preview every action the script would take without touching your system — perfect for auditing on shared or company machines.
- 🚄 **`--minimal` Mode**: Non-interactive core-only install (apt packages, Docker, `uv`). Great for fast CI server bootstraps.
- 🤖 **`--full` Mode**: Fully automated unattended install of everything. Perfect for CI/CD pipelines, provisioning scripts, and Dockerfiles.

---

## 🚀 Quick Start

### Option 1: Direct Execution (Recommended for fresh machines)

Run using process substitution so interactive prompts work correctly:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh)
```

On a minimal image without `wget`:

```bash
sudo apt-get update && sudo apt-get install -y wget && bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh)
```

### Option 2: Clone and Run

```bash
git clone https://github.com/Harshidpatel12/ubuntu-dev-setup.git
cd ubuntu-dev-setup
chmod +x setup.sh
./setup.sh
```

---

## 🎛️ CLI Flags & Modes

The script supports several flags for different use cases:

| Flag        | Description                                                |
| ----------- | ---------------------------------------------------------- |
| _(none)_    | Default interactive mode — prompts for each optional tool  |
| `--dry-run` | Preview all actions without modifying the system           |
| `--minimal` | Non-interactive: install core tools only (apt, Docker, uv) |
| `--full`    | Non-interactive: install everything automatically          |
| `--help`    | Show usage information and exit                            |

Flags can be combined. For example:

```bash
# Preview a full install without touching anything (great for auditing)
./setup.sh --dry-run --full

# Fast CI server bootstrap — core tools only, no questions
./setup.sh --minimal

# Fully automated workstation setup — no prompts at all
./setup.sh --full

# Non-interactive setup via curl in CI/CD pipelines
bash <(wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh) --full
```

### Use in CI / Docker

```dockerfile
# Example Dockerfile snippet
RUN apt-get update && apt-get install -y curl wget sudo && \
    wget -qO setup.sh https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh && \
    chmod +x setup.sh && ./setup.sh --full
```

---

## 🛠️ Detailed Stack Breakdown

Here is exactly what gets installed and configured:

### 1. System Packages

The script updates your local package lists and installs the following:

- **Version Control**: `git`, `gh` (official GitHub CLI)
- **Network & Fetching**: `curl`, `openssh-server`, `openssh-client`
- **Diagnostics & Monitoring**: `htop`, `lsof`, `jq`
- **Compilers & Build Tools**: `build-essential` (gcc, g++, make)
- **Text Editors**: `vim`
- **Utilities**: `tldr` (simplified man pages), `bash-completion`

### 2. Docker Setup

- Installs official Docker engine using Docker's secure bootstrap script.
- Adds your current user to the `docker` group so you don't have to type `sudo` for every command.
- Sets up Docker CLI shell completion rules under `/etc/bash_completion.d/`.

### 3. Astral `uv` (Python)

- Installs `uv`, a drop-in replacement for `pip`, `pip-tools`, and `virtualenv` written in Rust.
- Speeds up Python package installations by 10-100x.
- Registers `uv` shell autocompletion in your `~/.bashrc`.

### 4. Custom Shell Aliases

Appends a dedicated block of developer aliases to your `~/.bashrc` (safely and idempotently):

- `gs` $\rightarrow$ `git status`
- `dco` $\rightarrow$ `docker compose`
- `dps` $\rightarrow$ `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`

### 5. System Optimizations

For large codebases, IDEs can quickly hit the default Linux file-watcher limit. The script increases `fs.inotify.max_user_watches` to `524288` inside `/etc/sysctl.d/99-dev-tweaks.conf`.

### 6. Node.js & FNM (Optional)

- Installs Fast Node Manager (`fnm`), an ultra-fast Node.js version manager written in Rust.
- Automatically downloads and configures the latest Node.js LTS version.

### 7. Rust Toolchain (Optional)

- Installs [`rustup`](https://rustup.rs/) — the official Rust toolchain installer — in non-interactive mode.
- Appends `source ~/.cargo/env` to all detected shell profiles so `cargo`, `rustc`, and `rustup` are available immediately after a terminal restart.
- Skips installation if `rustc` is already on `$PATH`.

### 8. Go Toolchain (Optional)

- Fetches the latest stable Go release version directly from `go.dev/VERSION` and downloads the official Linux tarball.
- Installs Go into `/usr/local/go` and cleans up the temporary archive.
- Injects both `/usr/local/go/bin` and `~/go/bin` (`$GOPATH/bin`) into all shell profiles idempotently.

### 9. Starship Prompt (Optional)

- Installs [Starship](https://starship.rs/) using the official one-line install script in `--yes` (non-interactive) mode.
- Appends the correct `eval "$(starship init bash|zsh)"` hook to each detected shell profile.
- Safe to re-run — a guard marker prevents duplicate hook entries.

### 10. Modern CLI Utilities (Optional)

- Installs `fzf` (fuzzy finder) for interactive command-line searches.
- Installs `ripgrep` (`rg`) for rapid recursive file searching.
- Installs `bat` (a `cat` clone with syntax highlighting) and configures a `bat` command redirect so it launches natively on Ubuntu.

### 11. Desktop IDEs (Optional / GUI-only)

- Automatically checks if a display server is running (`$DISPLAY` or `$WAYLAND_DISPLAY`) to avoid installing graphical programs on remote headless servers or minimal CLI containers.
- Installs **VS Code** via Microsoft's official GPG-signed APT repository (recommended over snap for system terminal shell integration).
- Installs **PyCharm Community Edition** via canonical classic snap packages.

---

## 🔒 Security & Safety First

- **Idempotent Execution**: You can safely run this script multiple times. If Docker, `uv`, or specific aliases are already installed/present, the script will skip them.
- **No Destructive Overwrites**: The SSH key generator checks for the existence of `~/.ssh/id_ed25519` and will **never** overwrite your existing SSH keys.
- **Non-Root Safety**: Docker group permission changes are only applied to the actual user running the script, ensuring your root space stays clean.

---

## 📚 Tools & Official Documentation

Below is a reference list of the tools managed by this script, complete with their official documentation links:

| Tool                   | Category            | Purpose                                             | Documentation                                                      |
| :--------------------- | :------------------ | :-------------------------------------------------- | :----------------------------------------------------------------- |
| **Git**                | Core (Default)      | Distributed version control system                  | [git-scm.com](https://git-scm.com/doc)                             |
| **gh (GitHub CLI)**    | Core (Default)      | Official command-line client for GitHub             | [cli.github.com](https://cli.github.com/)                          |
| **Docker / Compose**   | Core (Default)      | Containerization engine & multi-container manager   | [docs.docker.com](https://docs.docker.com/)                        |
| **Astral `uv`**        | Core (Default)      | Blazing fast Python package installer and resolver  | [docs.astral.sh/uv](https://docs.astral.sh/uv/)                    |
| **curl**               | Core (Default)      | Command-line tool for transferring data with URLs   | [curl.se](https://curl.se/docs/)                                   |
| **jq**                 | Core (Default)      | Command-line JSON parser and processor              | [jqlang.github.io/jq](https://jqlang.github.io/jq/)                |
| **htop**               | Core (Default)      | Interactive process viewer and system monitor       | [htop.dev](https://htop.dev/)                                      |
| **vim**                | Core (Default)      | Terminal-based text editor                          | [vim.org](https://www.vim.org/docs.php)                            |
| **lsof**               | Core (Default)      | Utility to list open files and network ports        | [man7.org/lsof](https://man7.org/linux/man-pages/man8/lsof.8.html) |
| **build-essential**    | Core (Default)      | Compiler toolchains (gcc, g++, make, etc.)          | [gcc.gnu.org](https://gcc.gnu.org/)                                |
| **OpenSSH**            | Core (Default)      | Secure remote login protocol and agents             | [openssh.com](https://www.openssh.com/)                            |
| **tldr**               | Core (Default)      | Simplified, community-driven terminal man pages     | [tldr.sh](https://tldr.sh/)                                        |
| **bash-completion**    | Core (Default)      | Tab-completion rules for command-line tools         | [github.com/scop](https://github.com/scop/bash-completion)         |
| **FNM (Node Manager)** | Optional (Prompt)   | Blazing-fast Node.js version manager in Rust        | [fnm.vercel.app](https://fnm.vercel.app/)                          |
| **Node.js (LTS)**      | Optional (Prompt)   | JavaScript runtime environment                      | [nodejs.org](https://nodejs.org/en/docs)                           |
| **fzf**                | Optional (Prompt)   | Command-line fuzzy finder for files and history     | [github.com/fzf](https://github.com/junegunn/fzf)                  |
| **ripgrep (`rg`)**     | Optional (Prompt)   | Line-oriented search tool (modern grep replacement) | [github.com/ripgrep](https://github.com/BurntSushi/ripgrep)        |
| **bat**                | Optional (Prompt)   | Cat clone with syntax highlighting & Git diffs      | [github.com/bat](https://github.com/sharkdp/bat)                   |
| **Rust (rustup)**      | Optional (Prompt)   | Systems programming language and toolchain manager  | [rustup.rs](https://rustup.rs/)                                    |
| **Go (Golang)**        | Optional (Prompt)   | Statically typed compiled programming language      | [go.dev](https://go.dev/doc/)                                      |
| **Starship**           | Optional (Prompt)   | Cross-shell fast & customizable prompt              | [starship.rs](https://starship.rs/)                                |
| **VS Code**            | Optional (GUI Only) | Standard graphical code editor                      | [code.visualstudio.com](https://code.visualstudio.com/)            |
| **PyCharm Community**  | Optional (GUI Only) | Python integrated development environment           | [jetbrains.com/pycharm](https://www.jetbrains.com/pycharm/)        |

---

## 🛠️ Development & Formatting

To maintain consistent style rules and code quality, this project uses [pre-commit](https://pre-commit.com/) git hook checks.

To set up the pre-commit hooks locally:

1. Install `pre-commit` (using `uv` or `pip`):

   ```bash
   uv tool install pre-commit
   # Or using pip:
   pip install pre-commit
   ```

2. Register the Git hooks:
   ```bash
   pre-commit install
   ```

Now, every time you run `git commit`, your files will automatically be formatted using `shfmt` and `prettier`, and validated using `shellcheck`.

To run the checks manually on all files:

```bash
pre-commit run --all-files
```

---

## 🤝 Contributing

Contributions are welcome! If you want to add support for more tools, shells (like Zsh/Oh My Zsh), or configurations:

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
