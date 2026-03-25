#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def resolve_repo_root(explicit_repo_root: str | None) -> Path:
    if explicit_repo_root:
        return Path(explicit_repo_root).resolve()
    return Path(__file__).resolve().parents[3]


def path_is_inside_repo(path_value: str, repo_root: Path) -> bool | None:
    if not path_value or "$" in path_value:
        return None

    candidate = Path(path_value).expanduser()
    if not candidate.is_absolute():
        candidate = repo_root / candidate

    try:
        candidate.resolve().relative_to(repo_root)
    except ValueError:
        return False

    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate root .env against .env.example")
    parser.add_argument("--repo-root", help="Path to the repo root")
    args = parser.parse_args()

    repo_root = resolve_repo_root(args.repo_root)
    env_example_path = repo_root / ".env.example"
    env_path = repo_root / ".env"

    if not env_example_path.is_file():
        raise SystemExit(f"Missing .env.example: {env_example_path}")

    if not env_path.is_file():
        raise SystemExit(f"Missing .env: {env_path}")

    example_values = parse_env_file(env_example_path)
    actual_values = parse_env_file(env_path)
    ingress_mode = actual_values.get("INGRESS_MODE", example_values.get("INGRESS_MODE", "local"))

    missing_keys = [key for key in example_values if key not in actual_values]
    blank_keys = [key for key, value in actual_values.items() if key in example_values and value == ""]
    extra_keys = [key for key in actual_values if key not in example_values]
    path_warnings: list[str] = []

    if ingress_mode != "cloudflare":
        optional_cloudflare_keys = {
            "CLOUDFLARE_TUNNEL_ID",
            "CLOUDFLARE_TUNNEL_CREDENTIALS_FILE",
        }
        blank_keys = [key for key in blank_keys if key not in optional_cloudflare_keys]

    for key in ("DATA_ROOT", "TENANT_ENV_ROOT"):
        value = actual_values.get(key, "")
        inside_repo = path_is_inside_repo(value, repo_root)
        if inside_repo:
            path_warnings.append(f"{key} points inside the git checkout: {value}")

    print(f"Repo root: {repo_root}")
    print(f"Root env example: {env_example_path}")
    print(f"Root env: {env_path}")
    print("")

    if missing_keys:
        print("Missing keys in .env:")
        for key in missing_keys:
            print(f"  - {key}")
    else:
        print("Missing keys in .env: none")

    if blank_keys:
        print("Blank keys in .env:")
        for key in blank_keys:
            print(f"  - {key}")
    else:
        print("Blank keys in .env: none")

    if extra_keys:
        print("Extra keys in .env:")
        for key in extra_keys:
            print(f"  - {key}")
    else:
        print("Extra keys in .env: none")

    if path_warnings:
        print("Repo-local path warnings:")
        for warning in path_warnings:
            print(f"  - {warning}")
    else:
        print("Repo-local path warnings: none")

    print("")
    print("Effective root values:")
    for key in example_values:
        actual = actual_values.get(key, "<missing>")
        print(f"  {key}={actual}")

    return 1 if missing_keys or path_warnings else 0


if __name__ == "__main__":
    raise SystemExit(main())
