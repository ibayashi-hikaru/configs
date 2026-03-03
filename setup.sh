#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WITH_AI_TOOLS=0

log() {
  printf '[setup] %s\n' "$*"
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

  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    log "Tip: change default shell with: chsh -s $zsh_path"
  fi
}

main() {
  while (($#)); do
    case "$1" in
      --with-ai-tools)
        WITH_AI_TOOLS=1
        ;;
      *)
        log "Unknown option: $1"
        log "Usage: ./setup.sh [--with-ai-tools]"
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
    "$REPO_DIR/install_ai_tools.sh"
  fi

  ensure_default_shell_note
  log "Done"
}

main "$@"
