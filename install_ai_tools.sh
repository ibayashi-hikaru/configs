#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[ai-tools] %s\n' "$*"
}

die() {
  printf '[ai-tools] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_writable_npm_prefix() {
  local npm_prefix
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"

  if [[ -n "$npm_prefix" && -d "$npm_prefix" && -w "$npm_prefix" ]]; then
    return
  fi

  local user_prefix="$HOME/.npm-global"
  mkdir -p "$user_prefix"
  npm config set prefix "$user_prefix"
  log "Configured user npm prefix: $user_prefix"
  log "Add this to PATH if needed: $user_prefix/bin"
}

check_node_version() {
  local node_major
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if [[ "$node_major" -lt 18 ]]; then
    die "Node.js 18+ is required. Current: $(node -v)"
  fi
}

install_npm_package() {
  local package_name="$1"
  local bin_name="$2"

  if command -v "$bin_name" >/dev/null 2>&1; then
    log "$bin_name already found. Updating: $package_name"
  else
    log "Installing: $package_name"
  fi

  npm install -g "$package_name"
}

main() {
  case "$(uname -s)" in
    Darwin|Linux)
      ;;
    *)
      die "Unsupported OS. This installer targets macOS/Linux."
      ;;
  esac

  need_cmd node
  need_cmd npm
  check_node_version
  ensure_writable_npm_prefix

  # Official npm packages:
  # - Claude Code: @anthropic-ai/claude-code
  # - OpenAI Codex CLI: @openai/codex
  install_npm_package "@anthropic-ai/claude-code" "claude"
  install_npm_package "@openai/codex" "codex"

  log "Done"
  log "Next: run 'claude' and 'codex' once to complete authentication."
}

main "$@"
