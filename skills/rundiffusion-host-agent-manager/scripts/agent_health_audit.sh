#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck disable=SC1091
. "${REPO_ROOT}/scripts/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: bash skills/rundiffusion-host-agent-manager/scripts/agent_health_audit.sh [tenant-slug]
EOF
}

slug="${1:-}"
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

load_root_env
require_base_commands
require_command curl

result=0

echo "== Root env validation =="
if ! python3 "${SCRIPT_DIR}/validate_root_env.py" --repo-root "${REPO_ROOT}"; then
  result=1
fi

echo
echo "== Docker =="
if ! docker info >/dev/null 2>&1; then
  echo "Docker Desktop is not available to this shell."
  exit 2
fi
echo "Docker is available."

echo
echo "== Shared status =="
"${REPO_ROOT}/scripts/status.sh" || result=1

if [[ -z "${slug}" ]]; then
  exit "${result}"
fi

echo
echo "== Tenant context =="
python3 "${SCRIPT_DIR}/tenant_runtime_context.py" "${slug}" --repo-root "${REPO_ROOT}" || result=1

if ! tenant_exists "${slug}"; then
  echo "Unknown tenant: ${slug}"
  exit 2
fi

echo
echo "== Smoke test =="
if ! "${REPO_ROOT}/scripts/smoke-test.sh" --tenant "${slug}"; then
  result=1
  echo
  echo "Smoke test failed for ${slug}."
  container_id="$(tenant_container_id "${slug}")"
  if [[ -n "${container_id}" ]]; then
    echo
    echo "== Recent container logs (${container_id}) =="
    docker logs --tail 120 "${container_id}" || true
  fi
  echo
  echo "Likely next checks:"
  echo "  - Verify Docker Desktop is fully healthy."
  echo "  - Verify the tenant env file exists and has the expected credentials."
  echo "  - Verify Traefik and cloudflared status in ./scripts/status.sh."
  echo "  - If this followed a deploy, consider ./scripts/rollback.sh --tenant ${slug}."
else
  echo "Smoke test passed for ${slug}."
fi

exit "${result}"
