#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/backup.sh [--tenant slug | --all]
EOF
}

tenant_slug=""
backup_all=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)
      tenant_slug="$2"
      shift 2
      ;;
    --all)
      backup_all=1
      shift
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

load_root_env
require_base_commands

backup_one() {
  local slug="$1"
  local timestamp archive_dir archive_path temp_dir data_root env_file current_release image_ref

  tenant_exists "${slug}" || die "Unknown tenant: ${slug}"
  timestamp="$(date -u +%Y%m%d%H%M%S)"
  archive_dir="$(tenant_backup_root "${slug}")"
  archive_path="${archive_dir}/${slug}-${timestamp}.tgz"
  temp_dir="$(mktemp -d)"
  data_root="$(tenant_data_root "${slug}")"
  env_file="$(tenant_env_file "${slug}")"
  current_release="$(tenant_current_release "${slug}")"
  image_ref="$(tenant_release_image_ref "${slug}" "${current_release}")"

  ensure_directory "${archive_dir}"
  mkdir -p "${temp_dir}/data"
  [[ -d "${data_root}/gateway" ]] && cp -a "${data_root}/gateway" "${temp_dir}/data/gateway"
  [[ -f "${env_file}" ]] && cp "${env_file}" "${temp_dir}/tenant.env"

  cat > "${temp_dir}/metadata.json" <<EOF
{
  "slug": "${slug}",
  "hostname": "$(tenant_hostname "${slug}")",
  "data_root": "${data_root}",
  "env_file": "${env_file}",
  "current_release": "${current_release}",
  "image_ref": "${image_ref}",
  "created_at_utc": "${timestamp}"
}
EOF

  tar -czf "${archive_path}" -C "${temp_dir}" metadata.json tenant.env data
  rm -rf "${temp_dir}"
  note "Created ${archive_path}"
}

if [[ "${backup_all}" -eq 1 ]]; then
  while IFS= read -r slug; do
    [[ -n "${slug}" ]] || continue
    backup_one "${slug}"
  done <<EOF
$(tenant_slugs_all)
EOF
elif [[ -n "${tenant_slug}" ]]; then
  backup_one "${tenant_slug}"
else
  usage >&2
  exit 1
fi
