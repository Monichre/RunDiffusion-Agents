#!/usr/bin/env bash
set -euo pipefail

HEALTH_PORT="${PORT:-8080}"
HEALTH_URL="http://127.0.0.1:${HEALTH_PORT}/healthz"
WAIT_TIMEOUT_SECONDS="${RESTART_GATEWAY_WAIT_TIMEOUT_SECONDS:-120}"
POLL_INTERVAL_SECONDS="${RESTART_GATEWAY_POLL_INTERVAL_SECONDS:-1}"

gateway_pid() {
  pidof openclaw-gateway 2>/dev/null || true
}

wait_for_health() {
  local start_ts current_pid
  start_ts="$(date +%s)"

  while true; do
    current_pid="$(gateway_pid)"

    if [[ -n "${current_pid}" ]] && curl -fsS --max-time 5 "${HEALTH_URL}" >/dev/null 2>&1; then
      printf '%s\n' "${current_pid}"
      return 0
    fi

    if (( $(date +%s) - start_ts >= WAIT_TIMEOUT_SECONDS )); then
      return 1
    fi

    sleep "${POLL_INTERVAL_SECONDS}"
  done
}

current_pid="$(gateway_pid)"
if [[ -z "${current_pid}" ]]; then
  echo "[restart-openclaw-gateway] Could not find a running openclaw-gateway process."
  exit 1
fi

echo "[restart-openclaw-gateway] Signaling gateway pid ${current_pid} with SIGUSR1."
kill -USR1 "${current_pid}"

if new_pid="$(wait_for_health)"; then
  echo "[restart-openclaw-gateway] Gateway is healthy again at ${HEALTH_URL}."
  echo "[restart-openclaw-gateway] Current gateway pid: ${new_pid}"
  exit 0
fi

echo "[restart-openclaw-gateway] Timed out waiting for gateway health to recover at ${HEALTH_URL}."
exit 1
