# 🚀 ubuntu-dev-setup

[![OS](https://img.shields.io/badge/OS-Ubuntu-orange?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/shell-bash-blue?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

An automated, developer-focused bootstrap script to configure a fresh Ubuntu workstation into a high-productivity development environment in minutes.

Whether you are setting up a local machine, a fresh VM, or a remote server, **ubuntu-dev-setup** installs core utilities, configures containerization, sets up optimized system limits, configures rapid Python package tooling, registers helpful aliases, and sets up Git/SSH credentials securely.

---

## ✨ Features

- 📦 **Core Utilities & Toolchains**: Installs essential development packages (`git`, `gh`, `curl`, `jq`, `htop`, `vim`, `lsof`, `build-essential`, `openssh`).
- 🐳 **Docker Ecosystem**: Installs Docker Engine & Docker Compose (v2) from official Docker repositories, configures non-root access, and configures Docker CLI shell auto-completions.
- ⚡ **Lightning Fast Python**: Installs Astral's [`uv`](https://github.com/astral-sh/uv) (fast Python toolchain manager) and automatically configures shell autocompletions for Bash and Zsh.
- 🟨 **Interactive Node.js Setup (Optional)**: Prompts to install Fast Node Manager (`fnm`) and Node.js LTS, keeping your JavaScript setup modern and switchable.
- 🚀 **Modern CLI Power-ups (Optional)**: Prompts to install high-productivity command line utilities: `fzf` (fuzzy finder), `ripgrep` (search), and `bat` (enhanced cat with syntax highlighting).
- 🖥️ **Desktop IDEs (Optional / GUI-only)**: Safely detects a graphical desktop environment and offers to install **VS Code** (native Microsoft APT package) and **PyCharm Community** (classic Snap package).
- ⚙️ **Performance Tweaks**: Optimizes Linux file-watcher limits (`fs.inotify.max_user_watches`) to ensure smooth performance in heavy IDEs (like VS Code, IntelliJ, etc.).
- 💻 **Productive Environment**: Registers pre-configured, helpful shell aliases (e.g., `gs`, `dco`, `dps`) and PATH settings to **both Bash and Zsh** (via `~/.bashrc` and `~/.zshrc`).
- 🔑 **Interactive Identity Setup**: Guides you through configuring Git global settings and generates modern `Ed25519` SSH keys for GitHub/GitLab without overwriting existing keys.
- 🐳 **Container & Host Aware**: Automatically detects if it is running inside a Docker container (where root is the default) or on a host machine, adapting permissions and execution styles accordingly.

---

## 🚀 Quick Start

You can run the bootstrap script directly from GitHub (once hosted) or by cloning the repository locally.

### Option 1: Direct Execution (Recommended for fresh machines)

Run the script directly using `wget` (which is typically pre-installed on Ubuntu):

```bash
wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh | bash
```

If your machine is a minimal image and does not have `wget` installed, run this single command to install `wget` and execute the script:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -qO- https://raw.githubusercontent.com/Harshidpatel12/ubuntu-dev-setup/main/setup.sh | bash
```

### Option 2: Clone and Run

If you want to review or customize the script before execution:

```bash
# Clone the repository
git clone https://github.com/Harshidpatel12/ubuntu-dev-setup.git
cd ubuntu-dev-setup

# Make the script executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

---

## 🛠️ Detailed Stack Breakdown

Here is exactly what gets installed and configured:

### 1. System Packages
The script updates your local package lists and installs the following:
* **Version Control**: `git`, `gh` (official GitHub CLI)
* **Network & Fetching**: `curl`, `openssh-server`, `openssh-client`
* **Diagnostics & Monitoring**: `htop`, `lsof`, `jq`
* **Compilers & Build Tools**: `build-essential` (gcc, g++, make)
* **Text Editors**: `vim`
* **Utilities**: `tldr` (simplified man pages), `bash-completion`

### 2. Docker Setup
* Installs official Docker engine using Docker's secure bootstrap script.
* Adds your current user to the `docker` group so you don't have to type `sudo` for every command.
* Sets up Docker CLI shell completion rules under `/etc/bash_completion.d/`.

### 3. Astral `uv` (Python)
* Installs `uv`, a drop-in replacement for `pip`, `pip-tools`, and `virtualenv` written in Rust.
* Speeds up Python package installations by 10-100x.
* Registers `uv` shell autocompletion in your `~/.bashrc`.

### 4. Custom Shell Aliases
Appends a dedicated block of developer aliases to your `~/.bashrc` (safely and idempotently):
* `gs` $\rightarrow$ `git status`
* `dco` $\rightarrow$ `docker compose`
* `dps` $\rightarrow$ `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`

### 5. System Optimizations
For large codebases, IDEs can quickly hit the default Linux file-watcher limit. The script increases `fs.inotify.max_user_watches` to `524288` inside `/etc/sysctl.d/99-dev-tweaks.conf`.

### 6. Node.js & FNM (Optional)
* Installs Fast Node Manager (`fnm`), an ultra-fast Node.js version manager written in Rust.
* Automatically downloads and configures the latest Node.js LTS version.

### 7. Modern CLI Utilities (Optional)
* Installs `fzf` (fuzzy finder) for interactive command-line searches.
* Installs `ripgrep` (`rg`) for rapid recursive file searching.
* Installs `bat` (a `cat` clone with syntax highlighting) and configures a `bat` command redirect so it launches natively on Ubuntu.

### 8. Desktop IDEs (Optional / GUI-only)
* Automatically checks if a display server is running (`$DISPLAY` or `$WAYLAND_DISPLAY`) to avoid installing graphical programs on remote headless servers or minimal CLI containers.
* Installs **VS Code** via Microsoft's official GPG-signed APT repository (recommended over snap for system terminal shell integration).
* Installs **PyCharm Community Edition** via canonical classic snap packages.

---

## 🔒 Security & Safety First

* **Idempotent Execution**: You can safely run this script multiple times. If Docker, `uv`, or specific aliases are already installed/present, the script will skip them.
* **No Destructive Overwrites**: The SSH key generator checks for the existence of `~/.ssh/id_ed25519` and will **never** overwrite your existing SSH keys.
* **Non-Root Safety**: Docker group permission changes are only applied to the actual user running the script, ensuring your root space stays clean.

---

## 📚 Tools & Official Documentation

Below is a reference list of the tools managed by this script, complete with their official documentation links:

| Tool | Category | Purpose | Documentation |
| :--- | :--- | :--- | :--- |
| **Git** | Core (Default) | Distributed version control system | [git-scm.com](https://git-scm.com/doc) |
| **gh (GitHub CLI)** | Core (Default) | Official command-line client for GitHub | [cli.github.com](https://cli.github.com/) |
| **Docker / Compose** | Core (Default) | Containerization engine & multi-container manager | [docs.docker.com](https://docs.docker.com/) |
| **Astral `uv`** | Core (Default) | Blazing fast Python package installer and resolver | [docs.astral.sh/uv](https://docs.astral.sh/uv/) |
| **curl** | Core (Default) | Command-line tool for transferring data with URLs | [curl.se](https://curl.se/docs/) |
| **jq** | Core (Default) | Command-line JSON parser and processor | [jqlang.github.io/jq](https://jqlang.github.io/jq/) |
| **htop** | Core (Default) | Interactive process viewer and system monitor | [htop.dev](https://htop.dev/) |
| **vim** | Core (Default) | Terminal-based text editor | [vim.org](https://www.vim.org/docs.php) |
| **lsof** | Core (Default) | Utility to list open files and network ports | [man7.org/lsof](https://man7.org/linux/man-pages/man8/lsof.8.html) |
| **build-essential** | Core (Default) | Compiler toolchains (gcc, g++, make, etc.) | [gcc.gnu.org](https://gcc.gnu.org/) |
| **OpenSSH** | Core (Default) | Secure remote login protocol and agents | [openssh.com](https://www.openssh.com/) |
| **tldr** | Core (Default) | Simplified, community-driven terminal man pages | [tldr.sh](https://tldr.sh/) |
| **bash-completion** | Core (Default) | Tab-completion rules for command-line tools | [github.com/scop](https://github.com/scop/bash-completion) |
| **FNM (Node Manager)** | Optional (Prompt) | Blazing-fast Node.js version manager in Rust | [fnm.vercel.app](https://fnm.vercel.app/) |
| **Node.js (LTS)** | Optional (Prompt) | JavaScript runtime environment | [nodejs.org](https://nodejs.org/en/docs) |
| **fzf** | Optional (Prompt) | Command-line fuzzy finder for files and history | [github.com/fzf](https://github.com/junegunn/fzf) |
| **ripgrep (`rg`)** | Optional (Prompt) | Line-oriented search tool (modern grep replacement) | [github.com/ripgrep](https://github.com/BurntSushi/ripgrep) |
| **bat** | Optional (Prompt) | Cat clone with syntax highlighting & Git diffs | [github.com/bat](https://github.com/sharkdp/bat) |
| **VS Code** | Optional (GUI Only) | Standard graphical code editor | [code.visualstudio.com](https://code.visualstudio.com/) |
| **PyCharm Community** | Optional (GUI Only) | Python integrated development environment | [jetbrains.com/pycharm](https://www.jetbrains.com/pycharm/) |

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
