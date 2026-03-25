#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspaces/openclaw}"
SKILLS_DIR="${WORKSPACE_DIR}/skills"
LOCK_PATH="${WORKSPACE_DIR}/.skillhub-lock.json"
BOOTSTRAP_SKILLS="${BOOTSTRAP_SKILLS:-skillhub-manager,hello-world}"
BOOTSTRAP_FORCE="${BOOTSTRAP_FORCE:-0}"

SKILLHUB_URL="${SKILLHUB_URL:-}"
SKILLHUB_API_KEY="${SKILLHUB_API_KEY:-}"

if [[ -z "${SKILLHUB_URL}" || -z "${SKILLHUB_API_KEY}" ]]; then
  echo "[bootstrap] SKILLHUB_URL or SKILLHUB_API_KEY missing; skipping bootstrap."
  exit 0
fi

SKILLHUB_URL="${SKILLHUB_URL%/}"
mkdir -p "${SKILLS_DIR}"

trim_spaces() {
  printf '%s' "$1" | tr -d '[:space:]'
}

json_latest_version() {
  node -e '
    let data = "";
    process.stdin.on("data", (c) => (data += c));
    process.stdin.on("end", () => {
      try {
        const parsed = JSON.parse(data || "{}");
        const skill = parsed && parsed.skill ? parsed.skill : null;
        const latest = skill && typeof skill.latest === "string" ? skill.latest.trim() : "";
        process.stdout.write(latest);
      } catch {
        process.stdout.write("");
      }
    });
  '
}

update_lock() {
  local slug="$1"
  local version="$2"
  node - "${LOCK_PATH}" "${slug}" "${version}" <<'NODE'
const fs = require("fs");

const lockPath = process.argv[2];
const slug = process.argv[3];
const version = process.argv[4];

let doc = { updatedAt: null, installed: {} };
try {
  const raw = fs.readFileSync(lockPath, "utf8");
  const parsed = JSON.parse(raw);
  if (parsed && typeof parsed === "object") doc = parsed;
} catch {}

if (!doc.installed || typeof doc.installed !== "object") {
  doc.installed = {};
}

doc.installed[slug] = {
  version,
  source: "registry",
  installedAt: new Date().toISOString(),
};
doc.updatedAt = new Date().toISOString();

fs.mkdirSync(require("path").dirname(lockPath), { recursive: true });
fs.writeFileSync(lockPath, `${JSON.stringify(doc, null, 2)}\n`, "utf8");
NODE
}

download_and_install() {
  local slug="$1"
  local version="$2"
  local dst="${SKILLS_DIR}/${slug}"

  local tmpdir
  tmpdir="$(mktemp -d)"

  local zip_path="${tmpdir}/${slug}-${version}.zip"
  local extract_dir="${tmpdir}/extract"
  mkdir -p "${extract_dir}"

  local download_url="${SKILLHUB_URL}/v1/skills/${slug}/versions/${version}/download"
  curl -fsS \
    -H "x-api-key: ${SKILLHUB_API_KEY}" \
    "${download_url}" \
    -o "${zip_path}"

  unzip -q "${zip_path}" -d "${extract_dir}"

  local src=""
  if [[ -f "${extract_dir}/SKILL.md" ]]; then
    src="${extract_dir}"
  elif [[ -f "${extract_dir}/${slug}/SKILL.md" ]]; then
    src="${extract_dir}/${slug}"
  else
    for candidate in "${extract_dir}"/*; do
      [[ -d "${candidate}" ]] || continue
      if [[ -f "${candidate}/SKILL.md" ]]; then
        src="${candidate}"
        break
      fi
    done
  fi

  if [[ -z "${src}" ]]; then
    echo "[bootstrap] Could not locate SKILL.md in bundle for ${slug}@${version}"
    return 1
  fi

  if [[ -d "${dst}" ]]; then
    rm -rf "${dst}"
  fi
  mkdir -p "${dst}"
  cp -R "${src}/." "${dst}/"

  update_lock "${slug}" "${version}"
  echo "[bootstrap] Installed ${slug}@${version}"
  rm -rf "${tmpdir}"
}

IFS=',' read -r -a requested_skills <<< "${BOOTSTRAP_SKILLS}"

for requested in "${requested_skills[@]}"; do
  slug="$(trim_spaces "${requested}")"
  [[ -n "${slug}" ]] || continue

  dst="${SKILLS_DIR}/${slug}"
  if [[ -d "${dst}" && "${BOOTSTRAP_FORCE}" != "1" && "${BOOTSTRAP_FORCE}" != "true" ]]; then
    echo "[bootstrap] ${slug} already exists; skipping."
    continue
  fi

  meta_json="$(curl -fsS -H "x-api-key: ${SKILLHUB_API_KEY}" "${SKILLHUB_URL}/v1/skills/${slug}")"
  version="$(printf '%s' "${meta_json}" | json_latest_version)"

  if [[ -z "${version}" ]]; then
    echo "[bootstrap] Missing latest version for ${slug}"
    exit 1
  fi

  download_and_install "${slug}" "${version}"
done
