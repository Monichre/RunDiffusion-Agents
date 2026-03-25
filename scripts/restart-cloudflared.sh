#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
ingress_uses_cloudflare || die "INGRESS_MODE=${INGRESS_MODE}. Set INGRESS_MODE=cloudflare to restart cloudflared."
require_command launchctl
require_command curl

plist_path="$(launch_agent_path)"
require_file "${plist_path}"

if launchd_loaded; then
  launchctl kickstart -k "$(launchd_target)"
else
  launchctl bootstrap "gui/$(id -u)" "${plist_path}"
fi

for attempt in 1 2 3 4 5 6; do
  if cloudflared_ready; then
    note "cloudflared launch agent is healthy"
    exit 0
  fi
  sleep 2
done

die "cloudflared launch agent did not become healthy after restart"
