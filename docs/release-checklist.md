# Release Checklist

Use this before exporting the repo into the main OSS release repository.

## Safety

- Confirm no real `.env` files are present in the export
- Confirm no real tenant env files are present in the export
- Confirm no runtime state directories are present in the export
- Confirm `deploy/tenants/tenants.example.yml` is `tenants: []`
- Confirm `deploy/tenants/tenants.yml` is not included in the export

## Content Review

- Confirm the release-facing brand is `RunDiffusion Agents`
- Confirm the repo/export name is `rundiffusion-agents`
- Confirm `LICENSE`, `NOTICE`, `DISCLAIMER.md`, and `docs/license-audit.md` are present and current
- Confirm docs use placeholder domains such as `example.com`
- Confirm docs use placeholder usernames and host paths
- Confirm no real tenant names, slugs, or org-specific repo names remain
- Confirm no org-specific optional private registry service remains in the export
- Confirm proprietary or separately licensed integrations are described accurately, especially Claude Code
- Confirm the release-facing disclaimer still matches the current risk posture of the software
- Confirm the main README and deployment quickstarts visibly warn that operators use the software at their own risk
- Confirm any `@latest` third-party installs in the Dockerfile were re-audited for the release date

## Verification

- Run `node --test deploy/test/*.test.js` in the source repo before export
- Run `node --test test/*.test.js` in `services/rundiffusion-agents` before export
- Run `npm run build` in `services/rundiffusion-agents/dashboard`
- Run the release hygiene test

## Export

- Run `./scripts/export-oss-release.sh <destination>`
- Treat `scripts/export-oss-release.sh` as the source of truth for the OSS release filter
- Inspect the exported tree before pushing anywhere
- Initialize the destination as a brand-new repo before publishing
