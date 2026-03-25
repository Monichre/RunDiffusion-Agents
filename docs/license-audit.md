# License Audit

This is an engineering-facing license inventory for the current repo state as of
2026-03-25. It is not legal advice.

## Recommendation

- License the repository itself under Apache-2.0.
- Ship a root `NOTICE` file that states clearly that third-party components keep
  their own licenses and terms.
- Treat Claude Code as the main release risk: this repo can orchestrate it, but
  this repo's license does not make Claude Code open source or grant Anthropic
  usage rights.

## Scope

This audit was based on:

- the dashboard lockfile at
  [`services/rundiffusion-agents/dashboard/package-lock.json`](../services/rundiffusion-agents/dashboard/package-lock.json)
- the dashboard manifest at
  [`services/rundiffusion-agents/dashboard/package.json`](../services/rundiffusion-agents/dashboard/package.json)
- the standalone container build at
  [`services/rundiffusion-agents/Dockerfile`](../services/rundiffusion-agents/Dockerfile)
- the multi-tenant host stack at [`compose.prod.yml`](../compose.prod.yml)
- a live local gateway container sampled on 2026-03-25 to confirm currently
  installed global CLI versions

This document covers direct repo dependencies and the major bundled or
orchestrated components. It does not fully enumerate every Debian package pulled
in through `apt`, every Python transitive dependency pulled by Hermes extras, or
every upstream dependency installed inside OpenClaw's own build. Those remain a
second-pass item if you want a container-distribution-grade SBOM.

## High-Level Result

The repo is in a workable place for open-sourcing under Apache-2.0 because the
first-party code is your own and the direct dependency surface is mostly
permissive. The main things to watch are:

1. `@anthropic-ai/claude-code` is not open-source software.
2. The Dockerfile installs several CLIs with `@latest`, so future builds can
   drift in version and license posture.
3. Hermes and OpenClaw pull additional transitive dependencies outside this
   repo's lockfiles, so image-level audits are not yet reproducible from git
   alone.
4. The dashboard tree includes one attribution-style content license
   (`CC-BY-4.0`) and one weak-copyleft family (`MPL-2.0`), both of which should
   be documented but do not force this repo to become copyleft.

## Repo License Choice

Apache-2.0 is the best fit here because it:

- is compatible with your current direct dependency mix
- includes an explicit patent grant
- works well with a root `NOTICE` file
- makes it easier to say "our code is Apache-2.0, but third-party tools keep
  their own licenses and service terms"

MIT would also be possible, but Apache-2.0 gives you a cleaner release story for
an orchestration platform that mixes many upstream tools.

## Dashboard NPM Audit

The dashboard lockfile currently contains 189 resolved packages.

License counts from
[`services/rundiffusion-agents/dashboard/package-lock.json`](../services/rundiffusion-agents/dashboard/package-lock.json):

| License | Count | Notes |
| --- | ---: | --- |
| MIT | 163 | Most of the tree |
| MPL-2.0 | 12 | `lightningcss` toolchain packages |
| ISC | 7 | Includes `lucide-react` and small utilities |
| Apache-2.0 | 4 | Includes `typescript` and `class-variance-authority` |
| BSD-3-Clause | 1 | `source-map-js` |
| CC-BY-4.0 | 1 | `caniuse-lite` |
| 0BSD | 1 | `tslib` |

Direct dashboard dependencies:

| Package | Version | License |
| --- | --- | --- |
| `@radix-ui/react-dialog` | `1.1.15` | MIT |
| `class-variance-authority` | `0.7.1` | Apache-2.0 |
| `clsx` | `2.1.1` | MIT |
| `lucide-react` | `0.577.0` | ISC |
| `react` | `19.2.4` | MIT |
| `react-dom` | `19.2.4` | MIT |
| `tailwind-merge` | `3.5.0` | MIT |
| `@tailwindcss/vite` | `4.2.1` | MIT |
| `@types/node` | `25.5.0` | MIT |
| `@types/react` | `19.2.14` | MIT |
| `@types/react-dom` | `19.2.3` | MIT |
| `@vitejs/plugin-react` | `5.2.0` | MIT |
| `tailwindcss` | `4.2.1` | MIT |
| `typescript` | `5.9.3` | Apache-2.0 |
| `vite` | `7.3.1` | MIT |

Notable non-MIT items in the resolved tree:

- `caniuse-lite` is `CC-BY-4.0`
  This is an attribution-focused data license, so keep a third-party notice in
  the repo and do not imply it becomes Apache-2.0.
- `lightningcss` and its platform packages are `MPL-2.0`
  MPL is file-level copyleft. Using it as an unmodified dependency in the build
  toolchain does not require relicensing your repository, but modified
  `lightningcss` files would carry MPL obligations.

## Major Bundled Or Orchestrated Components

| Component | Where it appears | Version evidence | License or terms | Notes |
| --- | --- | --- | --- | --- |
| OpenClaw | Dockerfile global npm install | Dockerfile pins `OPENCLAW_VERSION`; installed sample showed `openclaw@2026.3.13` | MIT | Core bundled app |
| Hermes Agent | Dockerfile git clone + pip editable install | Dockerfile pins `HERMES_REF=v2026.3.12`; sampled container reported `hermes-agent 0.2.0` | MIT | Bundled delegated-task agent |
| OpenAI Codex CLI | Dockerfile global npm install | Sampled container reported `@openai/codex@0.116.0` | Apache-2.0 | Software is open source, but OpenAI service use still has separate terms |
| Google Gemini CLI | Dockerfile global npm install | Sampled container reported `@google/gemini-cli@0.35.0` | Apache-2.0 | Software is open source, but Google service use still has separate terms |
| Claude Code | Dockerfile global npm install | Sampled container reported `@anthropic-ai/claude-code@2.1.83` | Anthropic commercial terms | Main licensing red flag; not open-source software |
| FileBrowser Quantum | Docker multi-stage copy from `ghcr.io/gtsteffaniak/filebrowser:stable-slim` | Sampled container reported `v1.2.3-stable` | Apache-2.0 | Bundled binary copied into final image |
| ttyd | Dockerfile downloads GitHub release binary | Dockerfile pins `TTYD_VERSION=1.7.7`; sample showed `1.7.7-40e79c7` | MIT | Bundled terminal web bridge |
| tailscale | Dockerfile apt install from Tailscale repo | Sampled container reported `1.96.2` | BSD-3-Clause | Bundled in image |
| Homebrew/brew | Dockerfile installs Linuxbrew/Homebrew | Dockerfile installs HEAD script | BSD-2-Clause | Bundled developer tooling layer |
| Traefik | `compose.prod.yml` | Repo pins `traefik:v3.4` by default | MIT | Multi-tenant ingress |
| cloudflared | Docs and helper scripts | Host-managed, optional | Apache-2.0 | Not bundled in standalone image, but part of recommended host path |

## What To Worry About

### 1. Claude Code Is Not Open Source

This is the main thing that can confuse downstream users. A person seeing a
`/claude` route in an Apache-2.0 repository could incorrectly assume the tool
itself is Apache-2.0 too. It is not.

The current repo now addresses that by adding a root `NOTICE`, but the product
story should stay consistent everywhere you mention Claude Code.

### 2. `@latest` Means Audit Drift

The Dockerfile currently installs these without pinning a version in git:

- `@openai/codex@latest`
- `@anthropic-ai/claude-code@latest`
- `@google/gemini-cli@latest`

That means your next public build could change even if the repo does not. For a
repeatable OSS release, either pin these explicitly or re-audit them at release
time and update this document.

### 3. Image-Level Dependency Drift Still Exists

Two parts of the build pull in transitive dependencies that are not locked in
this repo:

- OpenClaw Control UI build:
  the Dockerfile downloads upstream OpenClaw source and runs `npm install`
- Hermes install:
  the Dockerfile clones Hermes and runs editable `pip install` commands

If you want a fully reproducible, image-level license bill of materials, pin or
lock those dependency trees as part of the release process.

## Upstream Source Pointers

Primary upstream references used for the major component licenses:

- [openclaw/openclaw](https://github.com/openclaw/openclaw)
- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- [openai/codex](https://github.com/openai/codex/releases)
- [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)
- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [gtsteffaniak/filebrowser](https://github.com/gtsteffaniak/filebrowser)
- [traefik/traefik](https://github.com/traefik/traefik)
- [cloudflare/cloudflared](https://github.com/cloudflare/cloudflared)
- [tailscale/tailscale](https://github.com/tailscale/tailscale)
- [tsl0922/ttyd](https://github.com/tsl0922/ttyd)
- [Homebrew/brew](https://github.com/Homebrew/brew)
