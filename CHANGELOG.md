# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] - 2026-06-20

### Added

- **`--dry-run` flag** — Preview all actions the script would take without modifying the system. Prints a full pre-flight check and post-install summary table.
- **`--minimal` flag** — Non-interactive mode: installs core apt packages, Docker, and `uv` only. Ideal for fast CI bootstraps.
- **`--full` flag** — Non-interactive mode: installs everything (core + Node.js, Rust, Go, Starship, CLI utilities) automatically without any prompts. Suitable for CI/CD pipelines.
- **`--help` flag** — Prints usage information and examples, then exits.
- **Pre-flight idempotency check** — On startup, scans for existing installations of all known tools (`git`, `gh`, `docker`, `uv`, `fnm`, `node`, `rustc`, `go`, `starship`, `fzf`, `rg`, `bat`, `code`) and displays their current versions. Users know exactly what will change before anything runs.
- **Post-install summary report** — At the end of execution, prints a clean formatted ASCII table showing every tool's status: newly installed (with version), already installed (with version), or skipped.
- **`run_cmd` helper** — Dry-run-aware wrapper that prints what a command would do instead of executing it when `--dry-run` is active.
- **`prompt_user` helper** — Mode-aware prompt that auto-answers `yes` in `--full` mode, `no` in `--minimal` mode, and falls back to interactive `read` in the default mode.
- **Rust toolchain support** — Optional install of `rustup` with the stable Rust toolchain; automatically configures `~/.cargo/env` in all detected shell profiles.
- **Go toolchain support** — Fetches the latest Go release from `go.dev/VERSION`, downloads and extracts it to `/usr/local/go`, and configures `$GOPATH/bin` in shell profiles.
- **Starship prompt support** — Optional install of [Starship](https://starship.rs) with automatic profile injection for both Bash and Zsh.
- **Modern CLI utilities** — Optional install of `fzf`, `ripgrep`, and `bat` (with `batcat` → `bat` symlink fix for Ubuntu).
- **Desktop IDE installs** — Optional VS Code (Microsoft APT) and PyCharm Community (Snap) installs, guarded by `$DISPLAY`/`$WAYLAND_DISPLAY` detection.
- **GitHub Actions: `test.yml`** — CI workflow that runs `setup.sh --dry-run --full` and `setup.sh --full` inside a fresh `ubuntu:22.04` container on every push and pull request.
- **GitHub Actions: `lint.yml`** — CI workflow running ShellCheck via pre-commit on every push and pull request.
- **Dependabot config** — Automatically keeps GitHub Actions versions up to date on a weekly schedule.
- **`CONTRIBUTING.md`** — Detailed contributor guide covering setup, code style (shfmt, ShellCheck), the `run_cmd`/`prompt_user`/`record_*` patterns, Docker-based testing, and PR guidelines.
- **`CHANGELOG.md`** — This file.
- **Colorized ANSI logging** — `log_step`, `log_info`, `log_success`, `log_warning`, `log_error`, `log_skip`, `log_dry` helpers for clearly readable terminal output.
- **Container-aware sudo detection** — Automatically detects if running as root (inside Docker) or as a normal user and adapts `sudo` usage accordingly.
- **Idempotent profile injection** — All shell profile additions (PATH entries, completions, aliases, Starship init) are guarded by unique marker comments to prevent duplicates on re-runs.
- **Astral `uv` Python toolchain** — Fast Rust-based Python package manager with automatic shell completion configuration for Bash and Zsh.
- **File watcher limit tweak** — Sets `fs.inotify.max_user_watches=524288` via `/etc/sysctl.d` for smooth IDE performance.
- **GitHub CLI (`gh`)** — Installed from the official GitHub CLI APT repository alongside core utilities.
- **Developer shell aliases** — `gs` (git status), `dco` (docker compose), `dps` (docker ps formatted table).

[Unreleased]: https://github.com/Harshidpatel12/ubuntu-dev-setup/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Harshidpatel12/ubuntu-dev-setup/releases/tag/v1.0.0
