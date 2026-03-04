#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WITH_AI_TOOLS=1
INSTALL_SYSTEM_PACKAGES=1
CHANGE_DEFAULT_SHELL=1
SETUP_GITHUB_SSH=1

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] ERROR: %s\n' "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif have_cmd sudo; then
    sudo "$@"
  else
    die "Need root privileges for: $* (sudo not found)"
  fi
}

install_packages_linux() {
  if have_cmd apt-get; then
    run_privileged apt-get update
    run_privileged apt-get install -y git curl zsh vim tmux openssh-client ca-certificates

    # NodeSource nodejs can conflict with apt's npm package.
    if ! have_cmd node; then
      if ! run_privileged apt-get install -y nodejs; then
        log "Could not install nodejs automatically"
      fi
    fi

    if ! have_cmd npm; then
      if ! run_privileged apt-get install -y npm; then
        log "Could not install npm via apt (possible nodejs/npm package conflict)"
      fi
    fi
    return
  fi

  if have_cmd dnf; then
    run_privileged dnf install -y git curl zsh vim tmux openssh-clients ca-certificates nodejs npm
    return
  fi

  if have_cmd yum; then
    run_privileged yum install -y git curl zsh vim tmux openssh-clients ca-certificates nodejs npm
    return
  fi

  if have_cmd pacman; then
    run_privileged pacman -Sy --noconfirm git curl zsh vim tmux openssh ca-certificates nodejs npm
    return
  fi

  if have_cmd zypper; then
    run_privileged zypper --non-interactive install git curl zsh vim tmux openssh ca-certificates nodejs20 npm20 || \
      run_privileged zypper --non-interactive install git curl zsh vim tmux openssh ca-certificates nodejs npm
    return
  fi

  die "Unsupported Linux package manager. Install git/curl/zsh/vim/tmux/node/npm manually."
}

install_packages_macos() {
  if ! have_cmd brew; then
    log "Homebrew not found. Skip package installation on macOS."
    log "Install manually: git curl zsh vim tmux node"
    return
  fi

  brew install git curl zsh vim tmux node
}

install_system_packages() {
  case "$(uname -s)" in
    Linux)
      install_packages_linux
      ;;
    Darwin)
      install_packages_macos
      ;;
    *)
      die "Unsupported OS. This setup targets macOS/Linux."
      ;;
  esac
}

current_login_shell() {
  if have_cmd getent; then
    getent passwd "$USER" | cut -d: -f7
    return
  fi

  if [[ "$(uname -s)" == "Darwin" ]] && have_cmd dscl; then
    dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
    return
  fi

  printf '%s\n' "${SHELL:-}"
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.backup.${TIMESTAMP}"
    mv "$target" "$backup"
    log "Backed up $target -> $backup"
  fi
}

link_dotfile() {
  local src="$1"
  local target="$2"

  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$src" ]]; then
    log "Skip (already linked): $target"
    return
  fi

  backup_if_exists "$target"
  mkdir -p "$(dirname "$target")"
  ln -s "$src" "$target"
  log "Linked $target -> $src"
}

install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "oh-my-zsh already exists"
    return
  fi

  log "Installing oh-my-zsh"
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
}

ensure_default_shell_note() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [[ -z "$zsh_path" ]]; then
    log "zsh not found; skip shell check"
    return
  fi

  local login_shell
  login_shell="$(current_login_shell)"

  if [[ "$login_shell" == "$zsh_path" ]]; then
    log "Default shell already set to zsh ($zsh_path)"
    return
  fi

  if [[ "$(uname -s)" == "Linux" ]] && [[ -f "/etc/shells" ]]; then
    if ! grep -Fx "$zsh_path" /etc/shells >/dev/null 2>&1; then
      if run_privileged tee -a /etc/shells >/dev/null <<<"$zsh_path"; then
        log "Added zsh to /etc/shells: $zsh_path"
      else
        log "Could not add zsh to /etc/shells automatically"
      fi
    fi
  fi

  if have_cmd chsh && chsh -s "$zsh_path" "$USER"; then
    log "Default shell changed to: $zsh_path (re-login required)"
    return
  fi

  if have_cmd chsh && run_privileged chsh -s "$zsh_path" "$USER"; then
    log "Default shell changed to: $zsh_path (re-login required)"
  else
    log "Could not change default shell automatically"
    log "Run manually: chsh -s $zsh_path"
  fi
}

main() {
  while (($#)); do
    case "$1" in
      --without-ai-tools)
        WITH_AI_TOOLS=0
        ;;
      --skip-system-packages)
        INSTALL_SYSTEM_PACKAGES=0
        ;;
      --skip-change-shell)
        CHANGE_DEFAULT_SHELL=0
        ;;
      --skip-github-ssh)
        SETUP_GITHUB_SSH=0
        ;;
      *)
        log "Unknown option: $1"
        log "Usage: ./setup.sh [--without-ai-tools] [--skip-system-packages] [--skip-change-shell] [--skip-github-ssh]"
        exit 1
        ;;
    esac
    shift
  done

  case "$(uname -s)" in
    Darwin|Linux)
      ;;
    *)
      log "Unsupported OS. This setup targets macOS/Linux."
      exit 1
      ;;
  esac

  if [[ "$INSTALL_SYSTEM_PACKAGES" -eq 1 ]]; then
    log "Installing base packages (git/curl/zsh/vim/tmux/node/npm)"
    install_system_packages
  else
    log "Skipping system package installation"
  fi

  install_oh_my_zsh

  link_dotfile "$REPO_DIR/_zshrc" "$HOME/.zshrc"
  link_dotfile "$REPO_DIR/_gitconfig" "$HOME/.gitconfig"
  link_dotfile "$REPO_DIR/_gitignore_global" "$HOME/.gitignore_global"
  link_dotfile "$REPO_DIR/_tmux.conf" "$HOME/.tmux.conf"
  link_dotfile "$REPO_DIR/_vimrc" "$HOME/.vimrc"

  if [[ ! -f "$HOME/.gitconfig.local" && -f "$REPO_DIR/_gitconfig.local.example" ]]; then
    cp "$REPO_DIR/_gitconfig.local.example" "$HOME/.gitconfig.local"
    log "Created local git config: $HOME/.gitconfig.local"
  fi

  mkdir -p "$HOME/.vim"
  link_dotfile "$REPO_DIR/colors" "$HOME/.vim/colors"

  mkdir -p "$HOME/.ssh"
  link_dotfile "$REPO_DIR/ssh_config" "$HOME/.ssh/config"
  if [[ ! -f "$HOME/.ssh/config.local" && -f "$REPO_DIR/ssh_config.local.example" ]]; then
    cp "$REPO_DIR/ssh_config.local.example" "$HOME/.ssh/config.local"
    chmod 600 "$HOME/.ssh/config.local"
    log "Created local ssh config: $HOME/.ssh/config.local"
  fi

  if [[ ! -f "$REPO_DIR/myShellConfig.sh" && -f "$REPO_DIR/myShellConfig.example.sh" ]]; then
    cp "$REPO_DIR/myShellConfig.example.sh" "$REPO_DIR/myShellConfig.sh"
    log "Created local override: $REPO_DIR/myShellConfig.sh"
  fi

  if [[ "$WITH_AI_TOOLS" -eq 1 ]]; then
    if ! "$REPO_DIR/install_ai_tools.sh"; then
      log "AI CLI installation failed; continue setup. Re-run: $REPO_DIR/install_ai_tools.sh"
    fi
  else
    log "Skipping AI CLI installation"
  fi

  if [[ "$SETUP_GITHUB_SSH" -eq 1 ]]; then
    if [[ -x "$REPO_DIR/setup_github_ssh.sh" ]]; then
      if ! "$REPO_DIR/setup_github_ssh.sh"; then
        log "GitHub/SSH setup failed; continue setup. Re-run: $REPO_DIR/setup_github_ssh.sh"
      fi
    else
      log "setup_github_ssh.sh not found or not executable; skip GitHub/SSH setup"
    fi
  else
    log "Skipping GitHub/SSH setup"
  fi

  if [[ "$CHANGE_DEFAULT_SHELL" -eq 1 ]]; then
    ensure_default_shell_note
  else
    log "Skipping default shell change"
  fi
  log "Done"
}

main "$@"
