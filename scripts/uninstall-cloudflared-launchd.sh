#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
require_command launchctl

plist_path="$(launch_agent_path)"

if [[ -f "${plist_path}" ]]; then
  launchctl bootout "gui/$(id -u)" "${plist_path}" >/dev/null 2>&1 || true
  rm -f "${plist_path}"
fi

note "Removed cloudflared launch agent"
