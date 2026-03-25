#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/export-oss-release.sh <destination>

Creates a fresh working copy of this repo for the main OSS release.

The export is driven by git-visible files in the working tree plus the explicit release
filter rules in this script. Ignored local state, tracked local tenant registry data,
and development-only test/scaffolding files are excluded from the exported tree.
EOF
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: missing required command: %s\n' "$1" >&2
    exit 1
  }
}

require_command git
require_command rsync

readonly RELEASE_EXCLUDES=(
  # Local deployment state that must never ship in the OSS tree.
  'deploy/tenants/tenants.yml'

  # Development-only test suites. Run these in the source repo before export.
  'deploy/test/'
  'services/rundiffusion-agents/test/'

  # UI generator metadata that is not used by the runtime or build.
  'services/rundiffusion-agents/dashboard/components.json'
)

is_release_excluded() {
  local relative_path="$1"
  local pattern

  for pattern in "${RELEASE_EXCLUDES[@]}"; do
    case "${pattern}" in
      */)
        [[ "${relative_path}" == "${pattern}"* ]] && return 0
        ;;
      *)
        [[ "${relative_path}" == "${pattern}" ]] && return 0
        ;;
    esac
  done

  return 1
}

destination_input="$1"
destination_parent="$(cd "$(dirname "${destination_input}")" && pwd -P)"
destination="${destination_parent}/$(basename "${destination_input}")"
repo_root="$(cd "${REPO_ROOT}" && pwd -P)"

case "${destination}" in
  "${repo_root}"|"${repo_root}"/*)
    printf 'error: destination must be outside the source repo\n' >&2
    exit 1
    ;;
esac

manifest_file="$(mktemp)"
trap 'rm -f "${manifest_file}"' EXIT

while IFS= read -r -d '' relative_path; do
  [[ -e "${repo_root}/${relative_path}" ]] || continue
  is_release_excluded "${relative_path}" && continue
  printf '%s\0' "${relative_path}" >> "${manifest_file}"
done < <(git -C "${repo_root}" ls-files -z --cached --others --exclude-standard)

rm -rf "${destination}"
mkdir -p "${destination}"

rsync -a --from0 --files-from="${manifest_file}" \
  "${repo_root}/" "${destination}/"

rm -rf "${destination}/.git"
git -C "${destination}" init -b main >/dev/null

printf 'Exported fresh release tree to %s\n' "${destination}"
