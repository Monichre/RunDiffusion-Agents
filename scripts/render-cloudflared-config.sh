#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
require_base_commands

if ! ingress_uses_cloudflare; then
  note "INGRESS_MODE=${INGRESS_MODE}; cloudflared config is not used"
  exit 0
fi

path="$(render_cloudflared_config)"
note "Rendered ${path}"
