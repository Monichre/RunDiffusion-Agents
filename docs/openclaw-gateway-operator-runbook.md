# OpenClaw Gateway Operator Runbook

This runbook covers the standalone single-tenant package under `services/rundiffusion-agents`.
For deployment, prefer the Docker Compose flow documented in
[`docs/standalone-host-quickstart.md`](./standalone-host-quickstart.md):

```bash
cd services/rundiffusion-agents
cp .env.example .env
docker compose up -d --build
docker compose logs -f
docker compose down
```

## Runtime contract

- env owns the wrapper contract: ports, auth mode, proxy credentials, workspace paths, and Control UI origin policy
- disk owns OpenClaw user state: model selection, provider auth, onboarding artifacts, and other upstream-created files under `/data/.openclaw`
- boot only writes the minimum gateway/workspace config needed for the wrapper to start OpenClaw cleanly
- boot does not pick a model, build provider-specific model lists, or seed OpenClaw auth profiles from env

## Required env

- `OPENCLAW_ACCESS_MODE=native` by default for OpenClaw's built-in token/device auth flow
- `OPENCLAW_ACCESS_MODE=trusted-proxy` when proxy Basic Auth should protect OpenClaw routes
- `OPENCLAW_GATEWAY_TOKEN=<long-random-secret>` to secure OpenClaw gateway auth
- `TERMINAL_BASIC_AUTH_USERNAME=<terminal-username>` and `TERMINAL_BASIC_AUTH_PASSWORD=<separate-password>` when any operator tty route is enabled
- `TERMINAL_ENABLED=1` if the in-box terminal should be exposed at `/terminal`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080,https://openclaw.example.com` for an explicit Control UI browser-origin allowlist

For vanilla native OpenClaw auth, the browser origin should be `localhost` or HTTPS. Plain HTTP
non-loopback origins are not a supported native device-approval path.

Optional env that still matters to sibling tools:

- `GEMINI_API_KEY` or `HERMES_OPENAI_API_KEY` for `/hermes`
- `OPENROUTER_API_KEY` for Hermes model switching
- `CODEX_OPENAI_API_KEY`, `CLAUDE_ANTHROPIC_API_KEY`, `GEMINI_CLI_API_KEY` only if you want those routes pre-authenticated instead of interactive login

## What boot touches

Every startup may write:

1. `/data/.openclaw/openclaw.json`
2. `/data/.openclaw/reconcile-summary.json`

The wrapper-managed `openclaw.json` fields are limited to:

- `gateway.mode`
- `gateway.port`
- `gateway.bind`
- `gateway.auth`
- `gateway.controlUi`
- `agents.defaults.workspace`

Everything else inside `openclaw.json` is treated as user-owned OpenClaw state and left alone.

Before rewriting `openclaw.json`, the runtime creates a timestamped `.bak-*` backup next to the
existing file.

## Readiness and health

- readiness
  - HTTP gateway is serving `/healthz` after OpenClaw, FileBrowser, and enabled operator tty listeners have bound their internal ports
  - the bootstrap summary exists at `/data/.openclaw/reconcile-summary.json`
- deeper wrapper health
  - `globalConfigAligned=true`
  - the expected gateway auth mode was applied
  - the expected Control UI origin policy was applied

Readiness no longer depends on model/provider detection. OpenClaw model auth is intentionally
left to the upstream onboarding flow and later runtime behavior.

## Reset procedure

Use the built-in reset command when you want a clean OpenClaw first boot without touching Hermes or
the other operator homes:

```bash
reset-openclaw-state
```

That command:

- loads `services/rundiffusion-agents/.env` when available, unless disabled
- backs up `/data/.openclaw`
- backs up `/data/workspaces/openclaw`
- removes only those OpenClaw-owned paths
- leaves `/data/.hermes`, `/data/.codex`, `/data/.claude`, and `/data/.gemini` alone

The default backup root is `/data/openclaw-reset-backups/<timestamp>`.

## Capture the known-good baseline

After you complete manual OpenClaw onboarding and confirm chat is working, snapshot that state:

```bash
capture-openclaw-baseline
```

That command copies:

- `/data/.openclaw`
- `/data/workspaces/openclaw`

The default capture root is `/data/openclaw-baselines/<timestamp>-manual-onboarding`.

Use that capture as the reference input for later merge/purge repair tooling.

## FileBrowser runtime

- public path: `/filebrowser`
- auth: same proxy Basic Auth as `/terminal`
- sources:
  - `/data`
  - `/data/workspaces/openclaw`
  - `/data/workspaces/hermes`
  - per-tool workspaces such as `/data/workspaces/codex`, `/data/workspaces/claude`, and `/data/workspaces/gemini`
  - `/data/tool-files`
  - `/app`

`/data/tool-files` is a browse-only aggregate view that groups:

- `/data/.hermes`
- `/data/.codex`
- `/data/.claude`
- `/data/.gemini`
- `/data/.openclaw`
- `/data/.filebrowser`

## Web terminal runtime

- public path: `/terminal`
- enable with: `TERMINAL_ENABLED=1`
- auth: proxy Basic Auth username/password when enabled, even if `/openclaw` is using native auth
- backend: `ttyd`
- persistence: shared `tmux` session named by `TERMINAL_SESSION_NAME`
- working directory: `/data/workspaces/openclaw`

The terminal route is intentionally blocked unless proxy Basic Auth is configured.

## Recovery checklist

1. Confirm `OPENCLAW_ACCESS_MODE` matches the intended dashboard auth strategy (`native` or `trusted-proxy`).
2. Confirm `OPENCLAW_GATEWAY_TOKEN` is set for native mode.
3. If `OPENCLAW_ACCESS_MODE=trusted-proxy`, confirm both `OPENCLAW_BASIC_AUTH_USERNAME` and `OPENCLAW_BASIC_AUTH_PASSWORD` are set together.
4. Confirm `TERMINAL_BASIC_AUTH_USERNAME` and `TERMINAL_BASIC_AUTH_PASSWORD` are set when `/terminal` or sibling tty routes are enabled.
5. If the browser shows `origin not allowed`, set `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` to the exact public origin you open in the browser.
6. If the browser shows `control ui requires device identity (use HTTPS or localhost secure context)`, move the browser origin to HTTPS or localhost. Plain HTTP LAN hostnames will not satisfy native device identity.
7. Redeploy the service if you changed env or routing.
8. Check startup logs and the wrapper summary artifact.

## Log signals to check

Look for the startup summary line:

```text
[reconcile] gatewayAuthMode=... openClawProxyAuthEnabled=... globalConfigChanged=... globalConfigAligned=...
```

Healthy deploys should show:

- the expected `gatewayAuthMode`
- `globalConfigAligned=true`

## Summary artifact

Boot writes `/data/.openclaw/reconcile-summary.json` with wrapper-focused data, including:

- gateway access mode
- gateway auth mode
- whether trusted-proxy auth is active
- allowed Control UI origins
- whether `openclaw.json` was changed
- whether the wrapper-managed fields are aligned
- repaired files and backup paths

For a compact operator view inside the runtime, run:

```bash
node /app/print_reconcile_summary.js
```

For automation, use the status wrapper:

```bash
/app/check_reconcile_status.sh
```

Exit codes:

- `0` = healthy
- `1` = warning
- `2` = broken or missing artifact

## Normal inspection checklist

- standalone deploy health should target `/healthz`
- inspect current env values on the host or platform
- inspect startup logs for the `[reconcile]` summary
- inspect startup logs for the proxy auth enabled/disabled line from `entrypoint`
- inspect startup logs for the `[filebrowser]` config line
- inspect startup logs for the `ttyd` and `tmux` startup lines for every enabled operator route
- inspect `/data/.openclaw/openclaw.json`
- inspect `/data/.openclaw/reconcile-summary.json`
- visit `/filebrowser` and confirm both `/data` and `/app` sources are visible
- visit `/terminal` and confirm the operator Basic Auth credentials work there
