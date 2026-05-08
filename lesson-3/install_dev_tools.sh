#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="${LOG_FILE:-install.log}"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

run_sudo() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

python_version_ok() {
  "${PYTHON_BIN:-python3}" - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 9) else 1)
PY
}

ensure_docker() {
  if command_exists docker; then
    log "Docker is already installed: $(docker --version)"
    return
  fi

  log "Docker is missing. Installing Docker..."
  if command_exists apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y docker.io
    if command_exists systemctl; then
      run_sudo systemctl enable --now docker || true
    fi
  elif command_exists brew; then
    brew install --cask docker || true
    log "Docker Desktop may require a manual first launch on macOS."
  else
    log "ERROR: unsupported OS. Install Docker manually and rerun this script."
    exit 1
  fi
}

compose_available() {
  docker compose version >/dev/null 2>&1 || docker-compose --version >/dev/null 2>&1
}

ensure_docker_compose() {
  if compose_available; then
    log "Docker Compose is already installed."
    return
  fi

  log "Docker Compose is missing. Installing Docker Compose..."
  if command_exists apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y docker-compose-plugin || run_sudo apt-get install -y docker-compose
  elif command_exists brew; then
    brew install docker-compose
  else
    log "ERROR: unsupported OS. Install Docker Compose manually and rerun this script."
    exit 1
  fi
}

ensure_python() {
  PYTHON_BIN="${PYTHON_BIN:-python3}"
  if command_exists "$PYTHON_BIN" && python_version_ok; then
    log "Python is already installed: $($PYTHON_BIN --version)"
    return
  fi

  log "Python >= 3.9 is missing. Installing Python..."
  if command_exists apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y python3 python3-pip python3-venv
    PYTHON_BIN=python3
    if python_version_ok; then
      log "Python installed: $($PYTHON_BIN --version)"
      return
    fi
  fi

  if command_exists pyenv; then
    pyenv install -s 3.11.9
    pyenv global 3.11.9
    PYTHON_BIN="$(pyenv which python)"
    log "Python installed via pyenv: $($PYTHON_BIN --version)"
    return
  fi

  log "ERROR: Python >= 3.9 is required. Install it manually or install pyenv."
  exit 1
}

ensure_pip() {
  if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    log "pip is already installed: $($PYTHON_BIN -m pip --version)"
    return
  fi

  log "pip is missing. Installing pip..."
  if "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1; then
    log "pip installed via ensurepip."
  elif command_exists apt-get; then
    run_sudo apt-get update
    run_sudo apt-get install -y python3-pip
  else
    log "ERROR: pip installation failed. Install pip manually and rerun this script."
    exit 1
  fi
}

python_module_available() {
  local module="$1"
  "$PYTHON_BIN" - "$module" <<'PY'
import importlib
import sys

module_name = sys.argv[1]
raise SystemExit(0 if importlib.util.find_spec(module_name) else 1)
PY
}

pip_install() {
  if "$PYTHON_BIN" -m pip install --upgrade --user "$@"; then
    return
  fi

  log "Retrying pip install with --break-system-packages for externally managed Python."
  "$PYTHON_BIN" -m pip install --upgrade --user --break-system-packages "$@"
}

ensure_python_packages() {
  local missing=()
  local item module package

  for item in "django:Django" "torch:torch" "torchvision:torchvision" "PIL:pillow"; do
    module="${item%%:*}"
    package="${item#*:}"
    if python_module_available "$module"; then
      log "Python package is already installed: $package"
    else
      missing+=("$package")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    return
  fi

  log "Installing missing Python packages: ${missing[*]}"
  pip_install "${missing[@]}"
}

print_versions() {
  log "Version check:"
  command_exists docker && docker --version || true
  docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || true
  "$PYTHON_BIN" --version
  "$PYTHON_BIN" -m pip --version
  "$PYTHON_BIN" - <<'PY'
import importlib

for module_name in ("django", "torch", "torchvision", "PIL"):
    module = importlib.import_module(module_name)
    version = getattr(module, "__version__", "unknown")
    print(f"{module_name}: {version}")
PY
}

main() {
  log "Starting idempotent DevOps/ML tools setup."
  ensure_docker
  ensure_docker_compose
  ensure_python
  ensure_pip
  ensure_python_packages
  print_versions
  log "Setup finished successfully."
}

main "$@"
