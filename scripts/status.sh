#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/lib/common.sh"

load_root_env
require_base_commands
require_command curl

echo "Shared Infrastructure"
echo "---------------------"
compose_shared ps || true
if smoke_test_shared_local 2>/dev/null; then
  echo "Traefik health: healthy"
else
  echo "Traefik health: unavailable"
fi
echo "Ingress mode: ${INGRESS_MODE}"
echo "Traefik bind: ${TRAEFIK_BIND_ADDRESS}:${TRAEFIK_HTTP_PORT}"

if ingress_uses_cloudflare; then
  if launchd_loaded; then
    echo "cloudflared launchd: loaded (${CLOUDFLARED_LAUNCHD_LABEL})"
  else
    echo "cloudflared launchd: not loaded (${CLOUDFLARED_LAUNCHD_LABEL})"
  fi

  if cloudflared_ready 2>/dev/null; then
    echo "cloudflared metrics: healthy ($(cloudflared_metrics_url))"
  else
    echo "cloudflared metrics: unavailable ($(cloudflared_metrics_url))"
  fi
else
  echo "cloudflared: disabled for INGRESS_MODE=${INGRESS_MODE}"
fi

echo
echo "Tenants"
echo "-------"
printf '%-18s %-10s %-18s %-20s %-14s %-32s\n' "SLUG" "ENABLED" "STATUS" "RELEASE" "OPENCLAW" "HOSTNAME"

while IFS= read -r slug; do
  [[ -n "${slug}" ]] || continue
  current_release="$(tenant_current_release "${slug}")"
  container_id="$(tenant_container_id "${slug}")"
  if [[ -n "${container_id}" ]]; then
    status="$(docker inspect --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "${container_id}")"
  else
    status="not-created"
  fi

  openclaw_version="$(tenant_release_openclaw_version "${slug}" "${current_release}")"
  if [[ -z "${openclaw_version}" ]]; then
    openclaw_version="<unknown>"
  fi

  printf '%-18s %-10s %-18s %-20s %-14s %-32s\n' \
    "${slug}" \
    "$(tenant_field_raw "${slug}" "enabled")" \
    "${status}" \
    "${current_release}" \
    "${openclaw_version}" \
    "$(tenant_hostname "${slug}")"
done <<EOF
$(tenant_slugs_all)
EOF
