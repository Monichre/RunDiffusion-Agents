#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

[[ $# -eq 1 ]] || die "Usage: ./scripts/stop-tenant.sh <slug>"

slug="$1"

load_root_env
require_base_commands
tenant_exists "${slug}" || die "Unknown tenant: ${slug}"

compose_tenant "${slug}" stop openclaw-gateway
note "Stopped tenant ${slug}"
