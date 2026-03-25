#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
require_base_commands

printf '%-18s %-8s %-36s %-24s\n' "SLUG" "ENABLED" "HOSTNAME" "PROJECT"
printf '%-18s %-8s %-36s %-24s\n' "------------------" "--------" "------------------------------------" "------------------------"

while IFS= read -r slug; do
  [[ -n "${slug}" ]] || continue
  printf '%-18s %-8s %-36s %-24s\n' \
    "${slug}" \
    "$(tenant_field_raw "${slug}" "enabled")" \
    "$(tenant_hostname "${slug}")" \
    "$(tenant_project_name "${slug}")"
done <<EOF
$(tenant_slugs_all)
EOF
