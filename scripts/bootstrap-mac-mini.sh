#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script is intended for macOS." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This deployment is tuned for Apple silicon. Current architecture: $(uname -m)" >&2
fi

install_homebrew() {
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

ensure_brew_formula() {
  local formula="$1"
  brew list "${formula}" >/dev/null 2>&1 || brew install "${formula}"
}

ensure_brew_cask() {
  local cask="$1"
  brew list --cask "${cask}" >/dev/null 2>&1 || brew install --cask "${cask}"
}

if ! command -v brew >/dev/null 2>&1; then
  install_homebrew
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

ensure_brew_formula git
ensure_brew_formula gh
ensure_brew_formula jq
ensure_brew_formula yq
ensure_brew_cask docker

cat <<'EOF'
Bootstrap finished.

Next steps:
1. Launch Docker Desktop once and complete its first-run setup.
2. In Docker Desktop settings, enable "Start Docker Desktop when you log in".
3. Copy `.env.example` to `.env` and set your host-specific values.
4. Choose an ingress mode in `.env`: local, direct, or cloudflare.
5. If you choose `INGRESS_MODE=cloudflare`, install `cloudflared`, create a tunnel, and run `./scripts/install-cloudflared-launchd.sh`.
EOF
