# OpenClaw Gateway Operator Notes

This service supports two auth modes for `/openclaw`:

- `OPENCLAW_ACCESS_MODE=native`: OpenClaw's built-in gateway token + device pairing flow
- `OPENCLAW_ACCESS_MODE=trusted-proxy`: nginx Basic Auth in front of OpenClaw

The current recommended deployment mode is `native`.

This image is intentionally a one-service path router. Keep `/openclaw` on native
OpenClaw auth and keep `/dashboard`, `/terminal`, `/filebrowser`, `/hermes`, `/codex`,
`/claude`, and `/gemini` as sibling paths on the same host unless you are deliberately
changing the service topology.

The recommended deployment path for this package is Docker Compose under
`services/rundiffusion-agents/`.
Use it for local single-tenant and remote single-tenant installs.
If you want the shared-host architecture with per-tenant routing, use the multi-tenant
Traefik stack from the repo root instead of forcing that model into this one-service guide.

The recommended restart mode is `OPENCLAW_NO_RESPAWN=0` so full-process gateway
restarts can complete under wrapper supervision. For local Docker debugging, avoid
`docker compose down` until you are done debugging, so the failed container and its logs stay inspectable.

Recommended package commands:

```bash
cd services/rundiffusion-agents
cp .env.example .env
docker compose up -d --build
docker compose logs -f
docker compose down
```

## Native operator flow

In native mode, the operator uses:

- `/dashboard` as the operator landing page for the sibling tools and built-in utilities
- `/openclaw` for the OpenClaw dashboard
- `/terminal` for shell access, recovery, and device approval
- `/hermes` for the quick drop-in Hermes experience
- `/codex` for the quick drop-in OpenAI Codex CLI experience
- `/claude` for the quick drop-in Claude Code experience
- `/gemini` for the quick drop-in Gemini CLI experience

Required env shape for the recommended standalone native deployment:

```env
OPENCLAW_ACCESS_MODE=native
OPENCLAW_GATEWAY_TOKEN=<long-random-secret>

TERMINAL_ENABLED=1
TERMINAL_BASIC_AUTH_USERNAME=<terminal-username>
TERMINAL_BASIC_AUTH_PASSWORD=<separate-terminal-password>
HERMES_ENABLED=1
CODEX_ENABLED=1
CLAUDE_ENABLED=1
GEMINI_ENABLED=0
```

`OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` is optional when `RAILWAY_PUBLIC_DOMAIN` matches the
browser origin. Set it explicitly for custom domains, multiple origins, or any host where you
prefer an exact allowlist. For the recommended local Docker path, set it to
`http://127.0.0.1:8080,http://localhost:8080`.

Vanilla native OpenClaw auth expects the Control UI browser session to use HTTPS or another secure
context such as localhost. Plain HTTP LAN hostnames are not a supported vanilla device-approval
path. If you move this service behind a non-loopback hostname, use HTTPS or intentionally switch to
`trusted-proxy`.

`/dashboard` and `/filebrowser` share the same Basic Auth credentials as `/terminal`.

OpenClaw now boots without a wrapper-selected model or provider profile. The
wrapper only keeps the gateway auth/path/workspace contract in place. Use the
OpenClaw UI to do the first model/provider onboarding so the resulting files in
`/data/.openclaw` reflect upstream behavior.

`/hermes` starts Hermes in its own shared tmux session. Hermes uses:

- `HERMES_HOME=/data/.hermes` for persistent config, sessions, memories, and logs
- `HERMES_WORKSPACE_DIR=/data/workspaces/hermes` by default, unless you override it
- `GEMINI_API_KEY` by default for auth against Google's OpenAI-compatible endpoint
- `HERMES_OPENAI_API_KEY` only if you want Hermes to use a different key than OpenClaw
- `OPENROUTER_API_KEY` optionally for first-class OpenRouter model switching inside Hermes

Set `HERMES_ENABLED=0` if you want to disable `/hermes`.

`/codex` starts OpenAI Codex CLI in its own tmux session. Codex uses:

- `CODEX_HOME=/data/.codex` for persistent config and auth cache
- `CODEX_WORKSPACE_DIR=/data/workspaces/codex` by default, unless you override it
- interactive Codex login by default, or `CODEX_OPENAI_API_KEY` only if you intentionally want pre-auth

Set `CODEX_ENABLED=0` if you want to disable `/codex`.

`/claude` starts Claude Code in its own tmux session. Claude uses:

- `CLAUDE_HOME=/data/.claude` for persistent config and auth state
- `CLAUDE_WORKSPACE_DIR=/data/workspaces/claude` by default, unless you override it
- interactive Claude login by default, or `CLAUDE_ANTHROPIC_API_KEY` only if you intentionally want pre-auth

Set `CLAUDE_ENABLED=0` if you want to disable `/claude`.

`/gemini` starts Gemini CLI in its own tmux session. Gemini uses:

- `GEMINI_HOME=/data/.gemini` for persistent config and auth state
- `GEMINI_WORKSPACE_DIR=/data/workspaces/gemini` by default, unless you override it
- interactive Gemini login by default, or `GEMINI_CLI_API_KEY` only if you intentionally want pre-auth

Set `GEMINI_ENABLED=0` if you want to disable `/gemini`.

On the multi-tenant host deployment, `/codex`, `/claude`, `/gemini`, and future sibling CLI
routes all share the same tenant `openclaw-gateway` container runtime. If namespace-dependent tool
calls fail there, adjust the host root `.env` with `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns`,
redeploy the tenant, and escalate to `privileged` only if `unshare -U true` still fails inside the
container.

## Workspace layout

By default, the operator routes now use separate workspaces:

- `/terminal` uses `/data/workspaces/openclaw`
- `/hermes` uses `/data/workspaces/hermes`
- `/codex` uses `/data/workspaces/codex`
- `/claude` uses `/data/workspaces/claude`
- `/gemini` uses `/data/workspaces/gemini`

Each tool still gets its own persistent home for config and login state:

- `/data/.hermes`
- `/data/.codex`
- `/data/.claude`
- `/data/.gemini`

Codex, Claude, and Gemini now keep a clean workspace root by default. To switch into another
workspace tree, use FileBrowser Quantum's top-level workspace roots or `cd /data/workspaces/<name>`
from the terminal after the CLI hands control back to the shell.

FileBrowser Quantum exposes the OpenClaw, Hermes, Codex, Claude, and Gemini workspaces as top-level
roots.

FileBrowser keeps the user-facing roots flatter than the on-disk layout:

- `Deployment Data`
- `OpenClaw Workspace`
- `Hermes Workspace`
- `Codex Workspace`
- `Claude Workspace`
- `Gemini Workspace`
- `Tool Files`
- `Container App`

`Tool Files` groups the internal persistent state that operators may still need for recovery:

- Hermes home
- Codex home
- Claude home
- Gemini home
- OpenClaw state
- FileBrowser state

## Dashboard

`/dashboard` is a small embedded operator shell inside this service.

It provides:

- a left sidebar with `OpenClaw`, `Hermes`, `Codex`, `Claude Code`, `Gemini`, `Terminal`, and `FileBrowser`
- same-origin embedded views for the sibling tools when iframe rendering is viable
- `Open in new tab` escape hatches for every tool
- a `Utilities` section with web wrappers for device approval and gateway restart

`/dashboard` is protected by the same Basic Auth include as `/terminal` and `/filebrowser`.

`/openclaw` still keeps its existing auth mode. In the recommended native deployment, the
dashboard does not replace OpenClaw token or device approval. It simply gives the operator a
clean place to launch the tools and run the lightweight helpers.

## OpenRouter in Hermes

When `OPENROUTER_API_KEY` is set:

- `/hermes` still boots on `google/gemini-3-flash-preview` by default
- Hermes can switch to these OpenRouter model IDs: `x-ai/grok-4.20-beta`, `xiaomi/mimo-v2-flash`, `minimax/minimax-m2.5`, `moonshotai/kimi-k2.5`

## First login to `/openclaw`

1. Open `/openclaw`
2. Paste the `OPENCLAW_GATEWAY_TOKEN` into the dashboard token field
3. Click `Connect`
4. If the dashboard says `pairing required`, do not keep retrying
5. Open `/terminal`
6. Log in with `TERMINAL_BASIC_AUTH_USERNAME` / `TERMINAL_BASIC_AUTH_PASSWORD`
7. Run:

```bash
approve-device
```

8. Select the most recent pending browser device
9. Press Enter to approve it
10. Return to `/openclaw` and connect once

Repeated retries before approval can trigger rate limiting such as `Too many unauthorized attempts`.

## Reset and capture

Use these inside the container or the in-box terminal:

```bash
reset-openclaw-state
capture-openclaw-baseline
restart-openclaw-gateway
```

- `reset-openclaw-state` backs up and removes only the OpenClaw state/workspace paths.
- `capture-openclaw-baseline` snapshots the current OpenClaw state after you finish manual onboarding.
- `restart-openclaw-gateway` triggers the managed gateway process restart in-place and waits for `/healthz` to recover.
- Neither command touches Hermes, Codex, Claude, or Gemini home directories.

## Terminal behavior

- `/terminal` logs you into the shared shell tmux session for maintenance work and device approval in `/data/workspaces/openclaw`
- `/hermes` logs you into a separate shared tmux session and starts Hermes immediately
- `/codex` logs you into a separate shared tmux session and starts Codex immediately in `/data/workspaces/codex`
- `/claude` logs you into a separate shared tmux session and starts Claude Code immediately in `/data/workspaces/claude`
- `/gemini` logs you into a separate shared tmux session and starts Gemini CLI immediately in `/data/workspaces/gemini`
- Hermes runs with `TERMINAL_ENV=local` and `TERMINAL_CWD=$HERMES_WORKSPACE_DIR`
- Exiting Hermes returns you to `/bin/bash` in the same `/hermes` session
- If no `HERMES_OPENAI_API_KEY` or `GEMINI_API_KEY` is present, `/hermes` falls back to a shell even when `OPENROUTER_API_KEY` is set
- Use FileBrowser's top-level workspace roots or `cd /data/workspaces/<name>` when you need to switch from a CLI tool workspace to another tree
- Exiting Codex, Claude, or Gemini returns you to `/bin/bash` in their respective sessions

## Terminal rendering defaults

All operator terminal routes share the same browser terminal stack:

- `nginx`
- `ttyd` / `xterm.js`
- `tmux`
- the target shell or CLI

The image now ships with shared rendering defaults intended to make browser-hosted
TUIs behave more consistently across `/terminal`, `/hermes`, `/codex`, `/claude`,
and `/gemini`:

- `TTYD_TERMINAL_TYPE=xterm-256color`
- `TTYD_CLIENT_RENDERER_TYPE=dom`
- `TTYD_CLIENT_FONT_FAMILY=ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace`
- `TTYD_CLIENT_FONT_SIZE=14`
- `TTYD_CLIENT_SCROLLBACK=50000`
- `TERMINAL_LANG=C.UTF-8`
- `TERMINAL_LC_ALL=C.UTF-8`
- `TERMINAL_COLORTERM=truecolor`

If a specific browser or client machine still renders poorly, override those envs
at deploy time instead of forking the per-tool launcher scripts.

## `approve-device`

`approve-device` is included in the container image for native pairing approval.

It:

- lists pending device pairing requests
- shows request metadata in a terminal picker
- supports `Up` / `Down` and `j` / `k`
- approves the selected request on Enter

The picker shows:

- client
- platform
- remote IP
- request timestamp
- request id

## Operator recovery commands

Open `/terminal`, then use any of these commands:

List all pending and paired devices:

```bash
openclaw devices list --token "$OPENCLAW_GATEWAY_TOKEN"
```

Approve the most recent request directly:

```bash
openclaw devices approve --latest --token "$OPENCLAW_GATEWAY_TOKEN"
```

Clear all paired devices:

```bash
openclaw devices clear --yes --token "$OPENCLAW_GATEWAY_TOKEN"
```

## Notes

- `/openclaw` uses native OpenClaw auth in `native` mode and is not protected by nginx Basic Auth
- `/terminal` remains behind separate Basic Auth
- `/hermes` shares the same Basic Auth as `/terminal`
- `/codex`, `/claude`, and `/gemini` share the same Basic Auth as `/terminal`
- `/filebrowser` now shares the same Basic Auth as `/terminal`
- `openclaw onboard` should not be run inside this managed container because it can rewrite the persisted gateway config in ways that drift from the deployment contract
