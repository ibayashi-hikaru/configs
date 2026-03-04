#!/usr/bin/env bash
set -euo pipefail

INSTALL_PACKAGES=1
RUN_GH_AUTH=1
REGISTER_GITHUB_KEY=1
INTERACTIVE=1
EMAIL=""
GIT_NAME=""
GIT_EMAIL=""
KEY_PATH="${HOME}/.ssh/id_ed25519_github"
KEY_TITLE=""

log() {
  printf '[github-ssh] %s\n' "$*"
}

warn() {
  printf '[github-ssh] WARN: %s\n' "$*" >&2
}

die() {
  printf '[github-ssh] ERROR: %s\n' "$*" >&2
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

usage() {
  cat <<'EOF'
Usage:
  ./setup_github_ssh.sh [options]

Options:
  --email EMAIL           Email for SSH key comment (omit to prompt)
  --git-name NAME         Set global git user.name
  --git-email EMAIL       Set global git user.email
  --key-path PATH         SSH private key path (default: ~/.ssh/id_ed25519_github)
  --key-title TITLE       GitHub key title (default: <hostname>-<os>)
  --non-interactive       Disable prompts (use args/current git config only)
  --skip-install          Skip package installation (git/gh/ssh tools)
  --skip-gh-auth          Skip gh auth login
  --skip-gh-key-register  Skip uploading SSH public key to GitHub
  -h, --help              Show this help

Examples:
  ./setup_github_ssh.sh
  ./setup_github_ssh.sh --email you@example.com --git-name "Your Name"
  ./setup_github_ssh.sh --non-interactive --skip-install
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --email)
        [[ $# -ge 2 ]] || die "Missing value for --email"
        EMAIL="$2"
        shift 2
        ;;
      --git-name)
        [[ $# -ge 2 ]] || die "Missing value for --git-name"
        GIT_NAME="$2"
        shift 2
        ;;
      --git-email)
        [[ $# -ge 2 ]] || die "Missing value for --git-email"
        GIT_EMAIL="$2"
        shift 2
        ;;
      --key-path)
        [[ $# -ge 2 ]] || die "Missing value for --key-path"
        KEY_PATH="$2"
        shift 2
        ;;
      --key-title)
        [[ $# -ge 2 ]] || die "Missing value for --key-title"
        KEY_TITLE="$2"
        shift 2
        ;;
      --non-interactive)
        INTERACTIVE=0
        shift
        ;;
      --skip-install)
        INSTALL_PACKAGES=0
        shift
        ;;
      --skip-gh-auth)
        RUN_GH_AUTH=0
        shift
        ;;
      --skip-gh-key-register)
        REGISTER_GITHUB_KEY=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

read_with_default() {
  local prompt="$1"
  local default_value="$2"
  local value=""

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " value
    printf '%s\n' "${value:-$default_value}"
  else
    read -r -p "$prompt: " value
    printf '%s\n' "$value"
  fi
}

install_packages_macos() {
  if ! have_cmd brew; then
    die "Homebrew not found. Install brew first or use --skip-install."
  fi

  local packages=()
  have_cmd git || packages+=(git)
  have_cmd gh || packages+=(gh)

  if ((${#packages[@]} > 0)); then
    log "Installing packages via brew: ${packages[*]}"
    brew install "${packages[@]}"
  fi
}

install_packages_linux() {
  if have_cmd apt-get; then
    local base_packages=(git openssh-client curl ca-certificates)
    local optional_gh=(gh)
    log "Installing base packages via apt-get"
    run_privileged apt-get update
    run_privileged apt-get install -y "${base_packages[@]}"
    if ! have_cmd gh; then
      if ! run_privileged apt-get install -y "${optional_gh[@]}"; then
        warn "Could not install 'gh' via apt-get. Install manually: https://cli.github.com/"
      fi
    fi
    return
  fi

  if have_cmd dnf; then
    local packages=(git openssh-clients curl ca-certificates)
    log "Installing base packages via dnf"
    run_privileged dnf install -y "${packages[@]}"
    if ! have_cmd gh; then
      if ! run_privileged dnf install -y gh; then
        warn "Could not install 'gh' via dnf. Install manually: https://cli.github.com/"
      fi
    fi
    return
  fi

  if have_cmd yum; then
    local packages=(git openssh-clients curl ca-certificates)
    log "Installing base packages via yum"
    run_privileged yum install -y "${packages[@]}"
    if ! have_cmd gh; then
      if ! run_privileged yum install -y gh; then
        warn "Could not install 'gh' via yum. Install manually: https://cli.github.com/"
      fi
    fi
    return
  fi

  if have_cmd pacman; then
    local packages=(git openssh curl ca-certificates github-cli)
    log "Installing packages via pacman: ${packages[*]}"
    run_privileged pacman -Sy --noconfirm "${packages[@]}"
    return
  fi

  if have_cmd zypper; then
    local packages=(git openssh curl ca-certificates)
    log "Installing base packages via zypper"
    run_privileged zypper --non-interactive install "${packages[@]}"
    if ! have_cmd gh; then
      if ! run_privileged zypper --non-interactive install gh; then
        warn "Could not install 'gh' via zypper. Install manually: https://cli.github.com/"
      fi
    fi
    return
  fi

  die "Unsupported Linux package manager. Use --skip-install and install git/gh/openssh manually."
}

install_required_packages() {
  if [[ "$INSTALL_PACKAGES" -eq 0 ]]; then
    log "Skipping package installation"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      install_packages_macos
      ;;
    Linux)
      install_packages_linux
      ;;
    *)
      die "Unsupported OS. This script targets macOS and Linux."
      ;;
  esac
}

ensure_required_commands() {
  have_cmd git || die "git not found. Re-run without --skip-install or install git manually."
  have_cmd ssh-keygen || die "ssh-keygen not found. Install OpenSSH."
  have_cmd ssh-add || die "ssh-add not found. Install OpenSSH."
  if [[ "$REGISTER_GITHUB_KEY" -eq 1 || "$RUN_GH_AUTH" -eq 1 ]]; then
    have_cmd gh || die "gh not found. Re-run without --skip-install or install GitHub CLI manually."
  fi
}

collect_identity_inputs() {
  local current_git_name=""
  local current_git_email=""

  current_git_name="$(git config --global user.name 2>/dev/null || true)"
  current_git_email="$(git config --global user.email 2>/dev/null || true)"

  if [[ "$INTERACTIVE" -eq 1 ]]; then
    if [[ -z "$GIT_NAME" ]]; then
      GIT_NAME="$(read_with_default "Git user.name" "$current_git_name")"
    fi

    if [[ -z "$GIT_EMAIL" ]]; then
      GIT_EMAIL="$(read_with_default "Git user.email" "$current_git_email")"
    fi

    if [[ -z "$EMAIL" ]]; then
      EMAIL="$(read_with_default "SSH key email comment" "${GIT_EMAIL:-$current_git_email}")"
    fi
  fi

  if [[ -z "$GIT_NAME" ]]; then
    GIT_NAME="$current_git_name"
  fi

  if [[ -z "$GIT_EMAIL" ]]; then
    GIT_EMAIL="$current_git_email"
  fi

  if [[ -z "$EMAIL" ]]; then
    EMAIL="${GIT_EMAIL:-$current_git_email}"
  fi

  if [[ -z "$GIT_NAME" ]]; then
    warn "git user.name is empty. Set it later with: git config --global user.name \"Your Name\""
  fi

  if [[ -z "$GIT_EMAIL" ]]; then
    warn "git user.email is empty. Set it later with: git config --global user.email you@example.com"
  fi
}

set_git_identity() {
  if [[ -n "$GIT_NAME" ]]; then
    git config --global user.name "$GIT_NAME"
    log "Configured git user.name"
  fi

  if [[ -n "$GIT_EMAIL" ]]; then
    git config --global user.email "$GIT_EMAIL"
    log "Configured git user.email"
  elif [[ -n "$EMAIL" ]]; then
    if ! git config --global user.email >/dev/null 2>&1; then
      git config --global user.email "$EMAIL"
      log "Configured git user.email from --email"
    fi
  fi
}

generate_ssh_key() {
  local pub_key_path="${KEY_PATH}.pub"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  if [[ -f "$KEY_PATH" && -f "$pub_key_path" ]]; then
    log "SSH key already exists: $KEY_PATH"
    return
  fi

  if [[ -z "$EMAIL" ]]; then
    die "Email is required to generate a new SSH key. Re-run interactively or pass --email."
  fi

  if [[ -f "$KEY_PATH" && ! -f "$pub_key_path" ]]; then
    log "Public key not found. Regenerating public key from existing private key."
    ssh-keygen -y -f "$KEY_PATH" >"$pub_key_path"
    chmod 644 "$pub_key_path"
    return
  fi

  log "Generating SSH key: $KEY_PATH"
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
  chmod 600 "$KEY_PATH"
  chmod 644 "$pub_key_path"
}

ensure_ssh_agent() {
  local ssh_add_status=0
  set +e
  ssh-add -l >/dev/null 2>&1
  ssh_add_status=$?
  set -e

  if [[ "$ssh_add_status" -eq 2 ]]; then
    log "Starting ssh-agent"
    # shellcheck disable=SC2046
    eval "$(ssh-agent -s)" >/dev/null
  fi
}

add_key_to_agent() {
  local pub_key
  pub_key="$(cat "${KEY_PATH}.pub")"

  set +e
  ssh-add -L 2>/dev/null | grep -F "$pub_key" >/dev/null 2>&1
  local key_exists_status=$?
  set -e

  if [[ "$key_exists_status" -eq 0 ]]; then
    log "Key already loaded in ssh-agent"
    return
  fi

  case "$(uname -s)" in
    Darwin)
      if ssh-add --apple-use-keychain "$KEY_PATH" >/dev/null 2>&1; then
        log "Added key to ssh-agent and macOS keychain"
      elif ssh-add -K "$KEY_PATH" >/dev/null 2>&1; then
        log "Added key to ssh-agent and keychain (legacy flag)"
      else
        ssh-add "$KEY_PATH" >/dev/null
        log "Added key to ssh-agent"
      fi
      ;;
    Linux)
      ssh-add "$KEY_PATH" >/dev/null
      log "Added key to ssh-agent"
      ;;
    *)
      die "Unsupported OS. This script targets macOS and Linux."
      ;;
  esac
}

default_key_title() {
  local host
  host="$(hostname -s 2>/dev/null || hostname)"
  printf '%s-%s' "$host" "$(uname -s | tr '[:upper:]' '[:lower:]')"
}

ensure_gh_auth() {
  if [[ "$RUN_GH_AUTH" -eq 0 ]]; then
    log "Skipping gh authentication"
    return
  fi

  if gh auth status -h github.com >/dev/null 2>&1; then
    log "gh already authenticated for github.com"
    return
  fi

  log "Authenticating gh (browser flow may open)"
  gh auth login -h github.com -p ssh -w
}

register_ssh_key_to_github() {
  if [[ "$REGISTER_GITHUB_KEY" -eq 0 ]]; then
    log "Skipping GitHub key registration"
    return
  fi

  if ! gh auth status -h github.com >/dev/null 2>&1; then
    warn "gh is not authenticated; skipping GitHub SSH key registration"
    return
  fi

  local pub_key_path="${KEY_PATH}.pub"
  local current_key
  current_key="$(cat "$pub_key_path")"

  set +e
  gh api user/keys --jq '.[].key' 2>/dev/null | grep -Fx "$current_key" >/dev/null
  local exists_status=$?
  set -e

  if [[ "$exists_status" -eq 0 ]]; then
    log "SSH public key is already registered on GitHub"
    return
  fi

  if [[ -z "$KEY_TITLE" ]]; then
    KEY_TITLE="$(default_key_title)"
  fi

  log "Registering SSH public key to GitHub (title: $KEY_TITLE)"
  gh ssh-key add "$pub_key_path" --title "$KEY_TITLE"
}

test_github_ssh() {
  local output
  local status=0
  set +e
  output="$(ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 1 ]] && [[ "$output" == *"successfully authenticated"* ]]; then
    log "GitHub SSH authentication test succeeded"
    return
  fi

  if [[ "$status" -eq 255 ]]; then
    warn "GitHub SSH test failed. Output: $output"
    return
  fi

  log "GitHub SSH test output: $output"
}

main() {
  parse_args "$@"

  if [[ ! -t 0 ]]; then
    INTERACTIVE=0
  fi

  case "$(uname -s)" in
    Darwin|Linux)
      ;;
    *)
      die "Unsupported OS. This script targets macOS and Linux."
      ;;
  esac

  install_required_packages
  ensure_required_commands
  collect_identity_inputs
  set_git_identity
  generate_ssh_key
  ensure_ssh_agent
  add_key_to_agent
  ensure_gh_auth
  register_ssh_key_to_github
  test_github_ssh

  log "Done"
  log "Public key: ${KEY_PATH}.pub"
}

main "$@"
