#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_RUNTIME_DIR="${OPENCLAW_RUNTIME_DIR:-/usr/local/lib/node_modules/openclaw}"
REAL_OPENCLAW_MODULE=""
ALLOW_SELF_UPDATE="${OPENCLAW_ALLOW_SELF_UPDATE:-0}"

resolve_real_openclaw_module() {
  local package_json="${OPENCLAW_RUNTIME_DIR}/package.json"
  local candidate=""

  if [[ -f "${package_json}" ]]; then
    candidate="$(
      node -e '
        const fs = require("node:fs");
        const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const bin = pkg.bin;
        const entry = typeof bin === "string" ? bin : (bin && bin.openclaw) || "";
        if (entry) {
          process.stdout.write(`${entry}\n`);
        }
      ' "${package_json}" 2>/dev/null || true
    )"
    if [[ -n "${candidate}" && -f "${OPENCLAW_RUNTIME_DIR}/${candidate}" ]]; then
      printf '%s\n' "${OPENCLAW_RUNTIME_DIR}/${candidate}"
      return 0
    fi
  fi

  for candidate in "openclaw.mjs" "dist/entry.js" "dist/index.js"; do
    if [[ -f "${OPENCLAW_RUNTIME_DIR}/${candidate}" ]]; then
      printf '%s\n' "${OPENCLAW_RUNTIME_DIR}/${candidate}"
      return 0
    fi
  done

  return 1
}

block_self_update() {
  if [[ "${ALLOW_SELF_UPDATE}" == "1" ]]; then
    return 1
  fi

  if [[ $# -gt 0 && "$1" == "update" ]]; then
    return 0
  fi

  local arg
  for arg in "$@"; do
    if [[ "${arg}" == "--update" ]]; then
      return 0
    fi
  done

  return 1
}

if ! REAL_OPENCLAW_MODULE="$(resolve_real_openclaw_module)"; then
  echo "[openclaw-wrapper] OpenClaw runtime entrypoint is missing under ${OPENCLAW_RUNTIME_DIR}." >&2
  exit 1
fi

if block_self_update "$@"; then
  echo "[openclaw-wrapper] Managed tenant deployments block in-container OpenClaw self-updates." >&2
  echo "[openclaw-wrapper] Redeploy the tenant from the repo to change the pinned OpenClaw version." >&2
  exit 64
fi

exec node "${REAL_OPENCLAW_MODULE}" "$@"
