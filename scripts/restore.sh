#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/restore.sh <backup-archive.tgz>
EOF
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 1
}

archive_path="$1"
require_file "${archive_path}"

load_root_env
require_base_commands
require_command curl

temp_dir="$(mktemp -d)"
tar -xzf "${archive_path}" -C "${temp_dir}"

metadata_file="${temp_dir}/metadata.json"
require_file "${metadata_file}"

tenant_slug="$(jq -r '.slug' "${metadata_file}")"
image_ref="$(jq -r '.image_ref // empty' "${metadata_file}")"

tenant_exists "${tenant_slug}" || die "Restore target ${tenant_slug} is not present in deploy/tenants/tenants.yml"

data_root="$(tenant_data_root "${tenant_slug}")"
env_file="$(tenant_env_file "${tenant_slug}")"

compose_tenant "${tenant_slug}" down --remove-orphans || true
rm -rf "${data_root}/gateway"
mkdir -p "${data_root}"
[[ -d "${temp_dir}/data/gateway" ]] && cp -a "${temp_dir}/data/gateway" "${data_root}/gateway"
[[ -f "${temp_dir}/tenant.env" ]] && cp "${temp_dir}/tenant.env" "${env_file}"

if [[ -n "${image_ref}" ]]; then
  export OPENCLAW_IMAGE="${image_ref}"
fi

compose_tenant "${tenant_slug}" up -d
wait_for_tenant_healthy "${tenant_slug}"
smoke_test_tenant_local "${tenant_slug}"

rm -rf "${temp_dir}"
note "Restored tenant ${tenant_slug} from ${archive_path}"
