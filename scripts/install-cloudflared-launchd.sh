#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
ingress_uses_cloudflare || die "INGRESS_MODE=${INGRESS_MODE}. Set INGRESS_MODE=cloudflare to install cloudflared."
require_command cloudflared
require_command launchctl
require_command curl

config_path="$(render_cloudflared_config)"
cloudflared_config_ready

log_dir="$(cloudflared_log_dir)"
log_path="$(cloudflared_log_path)"
plist_path="$(launch_agent_path)"
agent_dir="$(launch_agent_dir)"
cloudflared_bin="$(command -v cloudflared)"

ensure_directory "${log_dir}"
ensure_directory "${agent_dir}"
require_file "${LAUNCHD_TEMPLATE_FILE}"

tmp_plist="$(mktemp "${plist_path}.XXXXXX")"

sed \
  -e "s|__CLOUDFLARED_LABEL__|${CLOUDFLARED_LAUNCHD_LABEL}|g" \
  -e "s|__CLOUDFLARED_BIN__|${cloudflared_bin}|g" \
  -e "s|__CLOUDFLARED_CONFIG_PATH__|${config_path}|g" \
  -e "s|__CLOUDFLARED_LOG_PATH__|${log_path}|g" \
  -e "s|__REPO_ROOT__|${REPO_ROOT}|g" \
  "${LAUNCHD_TEMPLATE_FILE}" > "${tmp_plist}"

mv "${tmp_plist}" "${plist_path}"
chmod 644 "${plist_path}"

if launchd_loaded; then
  launchctl bootout "gui/$(id -u)" "${plist_path}" >/dev/null 2>&1 || true
fi

launchctl bootstrap "gui/$(id -u)" "${plist_path}"
launchctl kickstart -k "$(launchd_target)"

for attempt in 1 2 3 4 5 6; do
  if cloudflared_ready; then
    note "Installed and started cloudflared launch agent"
    note "Plist: ${plist_path}"
    note "Log: ${log_path}"
    exit 0
  fi
  sleep 2
done

die "cloudflared launch agent did not become healthy; inspect ${log_path}"
