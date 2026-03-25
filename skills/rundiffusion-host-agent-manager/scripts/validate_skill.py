#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from pathlib import Path

MAX_SKILL_NAME_LENGTH = 64


def resolve_skill_root(explicit_skill_root: str | None) -> Path:
    if explicit_skill_root:
        return Path(explicit_skill_root).resolve()
    return Path(__file__).resolve().parents[1]


def parse_frontmatter(skill_md: str) -> dict[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n", skill_md, re.DOTALL)
    if not match:
        raise ValueError("No valid YAML-style frontmatter found")

    frontmatter: dict[str, str] = {}
    for raw_line in match.group(1).splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if ":" not in line:
            raise ValueError(f"Invalid frontmatter line: {raw_line}")
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        frontmatter[key] = value
    return frontmatter


def validate_skill(skill_root: Path) -> list[str]:
    errors: list[str] = []
    skill_md_path = skill_root / "SKILL.md"

    if not skill_md_path.is_file():
        return [f"Missing SKILL.md: {skill_md_path}"]

    content = skill_md_path.read_text(encoding="utf-8")
    try:
        frontmatter = parse_frontmatter(content)
    except ValueError as exc:
        return [str(exc)]

    allowed_keys = {"name", "description"}
    unexpected_keys = sorted(set(frontmatter) - allowed_keys)
    if unexpected_keys:
        errors.append(
            "Unexpected frontmatter keys: " + ", ".join(unexpected_keys)
        )

    for required_key in ("name", "description"):
        if required_key not in frontmatter:
            errors.append(f"Missing frontmatter key: {required_key}")

    name = frontmatter.get("name", "")
    if name:
        if not re.fullmatch(r"[a-z0-9-]+", name):
            errors.append("Skill name must be lowercase hyphen-case")
        if name.startswith("-") or name.endswith("-") or "--" in name:
            errors.append("Skill name cannot start/end with hyphen or contain consecutive hyphens")
        if len(name) > MAX_SKILL_NAME_LENGTH:
            errors.append(f"Skill name exceeds {MAX_SKILL_NAME_LENGTH} characters")

    description = frontmatter.get("description", "")
    if not description:
        errors.append("Description must not be empty")
    if "<" in description or ">" in description:
        errors.append("Description cannot contain angle brackets")
    if len(description) > 1024:
        errors.append("Description exceeds 1024 characters")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a RunDiffusion skill")
    parser.add_argument("--skill-root", help="Path to the skill root")
    args = parser.parse_args()

    skill_root = resolve_skill_root(args.skill_root)
    errors = validate_skill(skill_root)
    if errors:
        print(f"Skill validation failed for: {skill_root}")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Skill is valid: {skill_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
