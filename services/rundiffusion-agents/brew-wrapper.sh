#!/usr/bin/env bash
set -euo pipefail

HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-${HOMEBREW_PREFIX}/Cellar}"
HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY:-${HOMEBREW_PREFIX}/Homebrew}"
BREW_USER="${HOMEBREW_RUN_AS_USER:-linuxbrew}"
BREW_BIN="${HOMEBREW_PREFIX}/bin/brew"

if [[ ! -x "${BREW_BIN}" ]]; then
  echo "[brew-wrapper] Homebrew is not installed in this image."
  exit 1
fi

if [[ "$(id -un)" == "${BREW_USER}" ]]; then
  exec "${BREW_BIN}" "$@"
fi

exec sudo -H -u "${BREW_USER}" env \
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX}" \
  HOMEBREW_CELLAR="${HOMEBREW_CELLAR}" \
  HOMEBREW_REPOSITORY="${HOMEBREW_REPOSITORY}" \
  PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH}" \
  "${BREW_BIN}" "$@"
