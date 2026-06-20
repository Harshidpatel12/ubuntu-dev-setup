# Contributing to ubuntu-dev-setup

Thank you for your interest in contributing! This guide will help you add new tools, improve the script, and submit high-quality pull requests.

---

## Table of Contents

- [Quick Start for Contributors](#quick-start-for-contributors)
- [Project Structure](#project-structure)
- [Code Style Guidelines](#code-style-guidelines)
- [Adding a New Tool or Section](#adding-a-new-tool-or-section)
- [Testing Your Changes](#testing-your-changes)
- [Pull Request Guidelines](#pull-request-guidelines)

---

## Quick Start for Contributors

```bash
# 1. Fork and clone the repo
git clone https://github.com/YOUR_USERNAME/ubuntu-dev-setup.git
cd ubuntu-dev-setup

# 2. Install pre-commit hooks (required — enforces code style automatically)
pip install pre-commit
pre-commit install

# 3. Create a feature branch
git checkout -b feat/add-my-new-tool

# 4. Make your changes, then verify all hooks pass
pre-commit run --all-files

# 5. Commit and push
git add .
git commit -m "feat: add <tool-name> support"
git push origin feat/add-my-new-tool

# 6. Open a Pull Request on GitHub
```

---

## Project Structure

```
ubuntu-dev-setup/
├── setup.sh                    # The main bootstrap script
├── .github/
│   ├── workflows/
│   │   ├── lint.yml            # Pre-commit linting CI
│   │   └── test.yml            # Full install test in Ubuntu container
│   └── dependabot.yml          # Automatic Actions version updates
├── .pre-commit-config.yaml     # Hook definitions (shfmt, shellcheck, prettier)
├── CONTRIBUTING.md             # This file
├── CHANGELOG.md                # Release history
├── LICENSE
└── README.md
```

---

## Code Style Guidelines

All code must pass the pre-commit hooks before a commit is accepted:

| Hook                  | Rule                                             |
| --------------------- | ------------------------------------------------ |
| `trailing-whitespace` | No trailing spaces on any line                   |
| `end-of-file-fixer`   | All files must end with a newline                |
| `shfmt`               | 4-space indent, redirect-after-statement (`-sr`) |
| `shellcheck`          | All shell scripts must pass ShellCheck v0.10.0   |
| `prettier`            | Markdown and YAML files formatted consistently   |

**Key Shell Script Rules:**

- Use 4-space indentation (enforced by `shfmt`)
- Use existing log helpers: `log_step`, `log_info`, `log_success`, `log_warning`, `log_error`, `log_skip`, `log_dry`
- Wrap any system-mutating commands with `run_cmd "Description" <actual command>` so `--dry-run` mode works
- Use `prompt_user "Question text"` instead of `read -rp` for optional installs so `--full` and `--minimal` modes bypass prompts automatically
- Track installed tools at the end of each section using `record_installed`, `record_already_installed`, or `record_skipped` for inclusion in the summary report
- Guard marker strings (e.g. `# --- AUTOMATED RUST PATH ---`) must be present for all profile injections to prevent duplicates on re-runs (idempotency)
- Add `# shellcheck disable=SCXXXX` comments (on the line immediately before) only when necessary — never suppress whole files

---

## Adding a New Tool or Section

Follow this pattern to add a new optional tool (e.g., `neovim`):

```bash
# --- Neovim ---
log_step "Neovim Text Editor"
if prompt_user "📝 Do you want to install Neovim?"; then
    if ! command -v nvim &>/dev/null; then
        log_info "Installing Neovim..."
        run_cmd "apt-get install neovim" $SUDO apt-get install -y neovim
        NVIM_VER=$(get_tool_version nvim --version)
        record_installed "Neovim" "$NVIM_VER"
        log_success "Neovim installed."
    else
        NVIM_VER=$(get_tool_version nvim --version)
        record_already_installed "Neovim" "$NVIM_VER"
        log_info "Neovim is already installed."
    fi
else
    record_skipped "Neovim"
    log_skip "Neovim installation"
fi
```

**Checklist for new tool additions:**

- [ ] Uses `prompt_user` for the prompt (not raw `read`)
- [ ] Wraps system commands in `run_cmd` (or equivalent `if [ "$DRY_RUN" = false ]` block for complex installs)
- [ ] Calls `record_installed` / `record_already_installed` / `record_skipped`
- [ ] Uses `get_tool_version` to capture version string
- [ ] Idempotent — safe to run multiple times on the same machine
- [ ] `pre-commit run --all-files` passes

---

## Testing Your Changes

### 1. Quick dry-run test (no system changes)

```bash
./setup.sh --dry-run --full
```

This runs the entire script in preview mode and prints the pre-flight check and summary table without touching your system.

### 2. Full test in a Docker container (recommended)

```bash
docker run -it --rm -v "$(pwd):/setup" ubuntu:22.04 bash -c \
  "apt-get update && apt-get install -y sudo curl wget && cd /setup && chmod +x setup.sh && ./setup.sh --full"
```

### 3. Minimal mode test

```bash
./setup.sh --dry-run --minimal
```

---

## Pull Request Guidelines

- **Keep PRs focused**: One tool or feature per PR.
- **Write descriptive commit messages** using [Conventional Commits](https://www.conventionalcommits.org/):
  - `feat: add <tool> support`
  - `fix: handle <edge case>`
  - `docs: update README for <feature>`
  - `chore: update pre-commit hook versions`
- **Update `CHANGELOG.md`** under the `[Unreleased]` section with a short description of your change.
- **Ensure CI passes**: Both `Lint Setup Script` and `Test Setup Script` workflows must be green.

---

We appreciate every contribution, no matter how small. Thank you! 🙏
