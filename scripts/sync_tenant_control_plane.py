#!/usr/bin/env python3

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

MANAGED_SECRET_KEYS = (
    "GEMINI_API_KEY",
    "GEMINI_CLI_API_KEY",
    "HERMES_OPENAI_API_KEY",
    "CODEX_OPENAI_API_KEY",
    "CLAUDE_ANTHROPIC_API_KEY",
    "OPENROUTER_API_KEY",
)
DEFAULT_PRIMARY_MODEL = "openai-codex/gpt-5.4"
DEFAULT_CODEX_MODEL = "gpt-5.4"
DEFAULT_CODEX_REASONING_EFFORT = "medium"
CONTAINER_CODEX_WORKSPACE = "/data/workspaces/codex"
CONTAINER_OPENCLAW_WORKSPACE = "/data/workspaces/openclaw"
GOOGLE_DEFAULT_PROFILE_ID = "google:default"
OPENCLAW_VERSION_RE = re.compile(r"^[0-9]{4}\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$")


def ensure_object(value):
    return value if isinstance(value, dict) else {}


def normalize_string(value):
    return str(value or "").strip()


def normalize_openclaw_version(control_plane_entry, tenant_slug):
    if not control_plane_entry:
        return ""
    version = normalize_string(control_plane_entry.get("openclawVersion"))
    if version and not OPENCLAW_VERSION_RE.fullmatch(version):
        raise SystemExit(
            f"Invalid openclawVersion '{version}' for tenant '{tenant_slug}'. "
            "Use an exact version such as 2026.3.22 or 2026.3.22-beta.1"
        )
    return version


def load_yaml_via_yq(path):
    config_path = normalize_string(path)
    if not config_path:
        return None

    target = Path(config_path)
    if not target.is_file():
        return None

    output = subprocess.run(
        ["yq", "-o=json", ".", str(target)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(output.stdout or "{}")


def load_control_plane_entry(path, slug):
    document = load_yaml_via_yq(path)
    if not document:
        return None

    tenants = document.get("tenants")
    if isinstance(tenants, dict):
        entry = tenants.get(slug)
        return entry if isinstance(entry, dict) else None

    if isinstance(tenants, list):
        for candidate in tenants:
            if isinstance(candidate, dict) and normalize_string(candidate.get("slug")) == slug:
                return candidate

    return None


def parse_env_file(path):
    values = {}
    target = Path(path)
    if not target.is_file():
        return values

    for raw_line in target.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = raw_line.split("=", 1)
        values[key.strip()] = value
    return values


def write_text_atomic(path, content, mode=0o600):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)

    current = target.read_text(encoding="utf-8") if target.is_file() else None
    if current == content:
        return False

    if target.exists():
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        backup_path = target.with_name(f"{target.name}.bak-control-plane-{timestamp}")
        shutil.copyfile(target, backup_path)

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False, dir=target.parent) as handle:
        handle.write(content)
        temp_path = Path(handle.name)

    os.chmod(temp_path, mode)
    temp_path.replace(target)
    return True


def safe_read_json(path):
    target = Path(path)
    if not target.is_file():
        return {}

    try:
        return json.loads(target.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def normalize_models_allowed(models_doc, primary_model):
    allowed = models_doc.get("allowed")
    if isinstance(allowed, list):
        values = [normalize_string(value) for value in allowed if normalize_string(value)]
        if values:
            return values
    return [primary_model]


def normalize_model_fallbacks(models_doc):
    raw = models_doc.get("fallbacks")
    if not isinstance(raw, list):
        return []
    return [normalize_string(value) for value in raw if normalize_string(value)]


def google_profile_hydration_enabled(control_plane_entry):
    providers = ensure_object(control_plane_entry.get("providers")) if control_plane_entry else {}
    google = ensure_object(providers.get("google"))
    return bool(google.get("hydrateAuth"))


def normalize_google_api_key(control_plane_entry):
    if not control_plane_entry:
        return ""
    secrets = ensure_object(control_plane_entry.get("secrets"))
    return normalize_string(secrets.get("GEMINI_API_KEY"))


def update_openclaw_auth_store(auth_store_path, control_plane_entry):
    target = Path(auth_store_path)
    store_exists = target.is_file()
    if control_plane_entry is None and store_exists:
        return False

    next_store = safe_read_json(target)
    if not isinstance(next_store, dict):
        next_store = {}

    profiles = ensure_object(next_store.get("profiles"))
    usage_stats = ensure_object(next_store.get("usageStats"))
    hydrate_google = google_profile_hydration_enabled(control_plane_entry)
    google_api_key = normalize_google_api_key(control_plane_entry)
    should_seed_google = hydrate_google and bool(google_api_key)

    if should_seed_google:
        profiles[GOOGLE_DEFAULT_PROFILE_ID] = {
            "type": "api_key",
            "provider": "google",
            "key": google_api_key,
        }
    else:
        profiles.pop(GOOGLE_DEFAULT_PROFILE_ID, None)
        usage_stats.pop(GOOGLE_DEFAULT_PROFILE_ID, None)

    next_store["version"] = int(next_store.get("version") or 1)
    next_store["profiles"] = profiles
    next_store["usageStats"] = usage_stats

    content = json.dumps(next_store, indent=2) + "\n"
    return write_text_atomic(target, content)


def update_global_openclaw_auth(global_config, control_plane_entry):
    next_config = global_config if isinstance(global_config, dict) else {}
    auth = ensure_object(next_config.get("auth"))
    profiles = ensure_object(auth.get("profiles"))
    order = ensure_object(auth.get("order"))
    hydrate_google = google_profile_hydration_enabled(control_plane_entry)
    google_api_key = normalize_google_api_key(control_plane_entry)
    should_seed_google = hydrate_google and bool(google_api_key)

    if should_seed_google:
        profiles[GOOGLE_DEFAULT_PROFILE_ID] = {
            "provider": "google",
            "mode": "api_key",
        }
        google_order = order.get("google")
        if not isinstance(google_order, list):
            google_order = []
        if GOOGLE_DEFAULT_PROFILE_ID not in google_order:
            google_order.append(GOOGLE_DEFAULT_PROFILE_ID)
        order["google"] = google_order
    else:
        profiles.pop(GOOGLE_DEFAULT_PROFILE_ID, None)
        order.pop("google", None)

    auth["profiles"] = profiles
    auth["order"] = order
    next_config["auth"] = auth
    return next_config


def update_openclaw_config(config_path, control_plane_entry):
    target = Path(config_path)
    current = safe_read_json(target)
    config_exists = target.is_file()

    if control_plane_entry is None and config_exists:
        return False

    next_config = current if isinstance(current, dict) else {}
    next_config = update_global_openclaw_auth(next_config, control_plane_entry)
    next_agents = ensure_object(next_config.get("agents"))
    next_defaults = ensure_object(next_agents.get("defaults"))

    models_doc = ensure_object(control_plane_entry.get("models")) if control_plane_entry else {}
    agents_doc = ensure_object(control_plane_entry.get("agents")) if control_plane_entry else {}
    main_agent_doc = ensure_object(agents_doc.get("main"))

    primary_model = normalize_string(models_doc.get("primary"))
    if not primary_model:
        if not config_exists:
            primary_model = DEFAULT_PRIMARY_MODEL
        else:
            return False

    allowed_models = normalize_models_allowed(models_doc, primary_model)
    fallback_models = normalize_model_fallbacks(models_doc)
    main_model = normalize_string(main_agent_doc.get("model")) or primary_model

    next_defaults["model"] = {"primary": primary_model}
    if fallback_models:
        next_defaults["model"]["fallbacks"] = fallback_models

    next_defaults["models"] = {model_id: {} for model_id in allowed_models}
    next_agents["defaults"] = next_defaults

    agent_list = next_agents.get("list")
    if not isinstance(agent_list, list):
        agent_list = []

    updated_main = False
    for agent in agent_list:
        if isinstance(agent, dict) and normalize_string(agent.get("id")) == "main":
            agent["model"] = main_model
            updated_main = True
            break

    if not updated_main:
        agent_list.append({"id": "main", "model": main_model})

    next_agents["list"] = agent_list
    next_config["agents"] = next_agents

    content = json.dumps(next_config, indent=2) + "\n"
    return write_text_atomic(target, content)


def replace_or_append_scalar(text, key, value):
    line = f'{key} = "{value}"'
    pattern = re.compile(rf"(?m)^{re.escape(key)}\s*=\s*.*$")
    if pattern.search(text):
        return pattern.sub(line, text, count=1)
    return f"{line}\n{text}" if text.strip() else f"{line}\n"


def ensure_toml_project(text, project_path):
    section_header = f'[projects."{project_path}"]'
    if section_header in text:
        section_pattern = re.compile(
            rf'(?ms)^\[projects\."{re.escape(project_path)}"\]\n(?:.+\n)*?(?=^\[|\Z)'
        )
        replacement = f'{section_header}\ntrust_level = "trusted"\n\n'
        return section_pattern.sub(replacement, text, count=1)

    separator = "" if not text or text.endswith("\n") else "\n"
    return f"{text}{separator}{section_header}\ntrust_level = \"trusted\"\n"


def ensure_notice_model_migration(text):
    section_header = "[notice.model_migrations]"
    entry_line = f'"gpt-5.3-codex" = "{DEFAULT_CODEX_MODEL}"'
    section_pattern = re.compile(r"(?ms)^\[notice\.model_migrations\]\n(?:.+\n)*?(?=^\[|\Z)")

    if section_header in text:
        match = section_pattern.search(text)
        if not match:
            return text
        section_body = match.group(0)
        if entry_line in section_body:
            return text
        replacement = f"{section_body.rstrip()}\n{entry_line}\n\n"
        return text[: match.start()] + replacement + text[match.end() :]

    separator = "" if not text or text.endswith("\n") else "\n"
    return f"{text}{separator}{section_header}\n{entry_line}\n"


def update_codex_config(config_path, control_plane_entry):
    target = Path(config_path)
    config_exists = target.is_file()
    if control_plane_entry is None and config_exists:
        return False

    text = target.read_text(encoding="utf-8") if config_exists else ""
    updated = text
    updated = replace_or_append_scalar(updated, "cli_auth_credentials_store", "file")
    updated = replace_or_append_scalar(updated, "model", DEFAULT_CODEX_MODEL)
    updated = replace_or_append_scalar(updated, "model_reasoning_effort", DEFAULT_CODEX_REASONING_EFFORT)
    updated = ensure_toml_project(updated, CONTAINER_CODEX_WORKSPACE)
    updated = ensure_toml_project(updated, CONTAINER_OPENCLAW_WORKSPACE)
    updated = ensure_notice_model_migration(updated)

    if not updated.endswith("\n"):
        updated = f"{updated}\n"

    return write_text_atomic(target, updated)


def build_managed_env(control_plane_entry, current_env):
    if not control_plane_entry:
        return {}

    secrets = ensure_object(control_plane_entry.get("secrets"))
    routes = ensure_object(control_plane_entry.get("routes"))
    gemini_route = ensure_object(routes.get("gemini"))
    managed = {}

    for key in MANAGED_SECRET_KEYS:
        managed[key] = normalize_string(secrets.get(key, ""))

    gemini_enabled = gemini_route.get("enabled")
    if isinstance(gemini_enabled, bool):
        managed["GEMINI_ENABLED"] = "1" if gemini_enabled else "0"
    elif "GEMINI_ENABLED" in current_env and normalize_string(current_env.get("GEMINI_ENABLED")):
        managed["GEMINI_ENABLED"] = normalize_string(current_env.get("GEMINI_ENABLED"))

    return managed


def write_managed_env(path, values):
    lines = ["# Managed by the RunDiffusion Agents control plane."]
    for key in sorted(values):
        lines.append(f"{key}={values[key]}")
    content = "\n".join(lines) + "\n"
    return write_text_atomic(path, content)


def main():
    parser = argparse.ArgumentParser(description="Sync control-plane managed tenant state.")
    parser.add_argument("--tenant-slug", required=True)
    parser.add_argument("--tenant-env-file", required=True)
    parser.add_argument("--tenant-managed-env-file", required=True)
    parser.add_argument("--tenant-data-root", required=True)
    parser.add_argument("--control-plane-config-path", default="")
    args = parser.parse_args()

    control_plane_entry = load_control_plane_entry(args.control_plane_config_path, args.tenant_slug)
    control_plane_openclaw_version = normalize_openclaw_version(control_plane_entry, args.tenant_slug)
    current_env = parse_env_file(args.tenant_env_file)
    managed_env = build_managed_env(control_plane_entry, current_env)
    managed_env_changed = write_managed_env(args.tenant_managed_env_file, managed_env)

    gateway_root = Path(args.tenant_data_root) / "gateway"
    auth_store_changed = update_openclaw_auth_store(
        gateway_root / ".openclaw" / "agents" / "main" / "agent" / "auth-profiles.json",
        control_plane_entry,
    )
    openclaw_changed = update_openclaw_config(
        gateway_root / ".openclaw" / "openclaw.json",
        control_plane_entry,
    )
    codex_changed = update_codex_config(
        gateway_root / ".codex" / "config.toml",
        control_plane_entry,
    )

    summary = {
        "tenant": args.tenant_slug,
        "controlPlaneEntry": control_plane_entry is not None,
        "controlPlaneOpenClawVersion": control_plane_openclaw_version,
        "managedEnvChanged": managed_env_changed,
        "authStoreChanged": auth_store_changed,
        "openclawConfigChanged": openclaw_changed,
        "codexConfigChanged": codex_changed,
    }
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
