# Configuration Layers

This repo has two deployment tracks and up to four configuration layers. Keep them separate.

## Deployment Tracks

- `standalone single tenant`
  Use the single-service `openclaw-gateway` deployment under `services/rundiffusion-agents` when
  you want one agent package on localhost or on a remote single-service host.
- `multi-tenant host`
  Use the Traefik + tenant stack when you want the intended shared-host architecture for LAN users,
  a cloud VM, or Cloudflare ingress.

Choose the deployment track first, then use the configuration layer for that track.

## 1. Root Host Config

Source:

- `.env.example`

Purpose:

- shared host paths
- shared ingress settings
- image build/deploy behavior
- tenant resource guardrails
- shared backup/release roots

Typical examples:

- `BASE_DOMAIN`
- `INGRESS_MODE`
- `PUBLIC_URL_SCHEME`
- `DATA_ROOT`
- `TENANT_ENV_ROOT`
- `TRAEFIK_BIND_ADDRESS`
- `TRAEFIK_HTTP_PORT`
- `CLOUDFLARE_TUNNEL_ID`
- `OPENCLAW_VERSION`
- `TENANT_CONTAINER_SECURITY_PROFILE`

Use this for the multi-tenant host stack only.
Do not use the root host config for the standalone single-tenant path.

Ingress mode notes:

- `INGRESS_MODE=local`
  Use this for same-host or LAN/private-network deployments. Keep `TRAEFIK_BIND_ADDRESS=127.0.0.1`
  for same-host access, or bind to a specific LAN IP for internal users. The host stack still works
  over plain HTTP on a LAN, but vanilla native `/openclaw` does not treat non-loopback HTTP origins
  as a secure context.
- `INGRESS_MODE=direct`
  Use this when Traefik should listen on a public or private interface directly. Set
  `TRAEFIK_BIND_ADDRESS=0.0.0.0` or a specific interface IP and point your own DNS at that host.
- `INGRESS_MODE=cloudflare`
  Use this when `cloudflared` should publish Traefik. In this mode the Cloudflare tunnel values
  become the active ingress config.

`PUBLIC_URL_SCHEME` controls the browser origin written into newly created tenant env files. The
generated `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` value uses the exact browser origin, including
`TRAEFIK_HTTP_PORT` when Traefik is not on `80` or `443`. Leave `PUBLIC_URL_SCHEME` blank to
auto-pick `https` for Cloudflare and `http` for local/direct installs.

## 2. Host Control-Plane Overrides

Source:

- `TENANT_CONTROL_PLANE_CONFIG_PATH` from the root `.env`
- example shape: `deploy/tenants/control-plane.example.yml`

Purpose:

- host-only per-tenant managed overrides
- per-tenant OpenClaw image version selection
- centralized provider/API key management
- OpenClaw model availability
- tenant-wide default model
- built-in `main` agent startup model
- selected route flags such as Gemini enablement

Typical examples:

- `openclawVersion`
- `secrets.GEMINI_API_KEY`
- `secrets.HERMES_OPENAI_API_KEY`
- `secrets.CLAUDE_ANTHROPIC_API_KEY`
- `models.allowed`
- `models.primary`
- `models.fallbacks`
- `agents.main.model`
- `routes.gemini.enabled`

Example:

```yaml
tenants:
  tenant-a:
    openclawVersion: 2026.3.24
    secrets:
      GEMINI_API_KEY: ""
      HERMES_OPENAI_API_KEY: ""
    models:
      allowed:
        - openai-codex/gpt-5.4
      primary: openai-codex/gpt-5.4
      fallbacks: []
    agents:
      main:
        model: openai-codex/gpt-5.4
    providers:
      google:
        hydrateAuth: false
    routes:
      gemini:
        enabled: false
```

Behavior:

- This file is optional and should stay outside git on real hosts.
- `openclawVersion` is a deploy-time tenant override for image selection. Precedence is:
  - `./scripts/deploy.sh --openclaw-version ...`
  - tenant `openclawVersion`
  - root `.env` `OPENCLAW_VERSION`
  - Dockerfile default
- When it exists and contains a tenant entry, it is authoritative only for the managed fields handled by deploy-time sync.
- Today that means it overrides older box-local values for:
  - managed provider/API keys
  - OpenClaw model availability
  - `agents.defaults.model`
  - `agents.list[id=main].model`
  - Gemini route enablement
- It also influences which OpenClaw image version `./scripts/deploy.sh --tenant <slug>` builds or selects for that tenant.
- It does not override:
  - gateway token
  - terminal/basic auth
  - hostname or allowed origins
  - Tailscale settings
  - non-`main` agents
  - operator Codex auth/session/profile state
- `openclawVersion` is not copied into tenant env files. It stays host-side and is consumed by the deploy tooling.

This layer is applied at deploy time, not continuously on boot.

Available parameters:

- `openclawVersion`
  Pin one tenant to a specific OpenClaw build without changing the host default for everyone else.
- `secrets.GEMINI_API_KEY`
- `secrets.GEMINI_CLI_API_KEY`
- `secrets.HERMES_OPENAI_API_KEY`
- `secrets.CODEX_OPENAI_API_KEY`
- `secrets.CLAUDE_ANTHROPIC_API_KEY`
- `secrets.OPENROUTER_API_KEY`
  Managed provider credentials applied at deploy time for that tenant.
- `models.allowed`
- `models.primary`
- `models.fallbacks`
  Tenant-wide OpenClaw model availability and default/fallback policy.
- `agents.main.model`
  Startup model for the built-in `main` agent.
- `providers.google.hydrateAuth`
  Controls Google auth hydration behavior for the tenant.
- `routes.gemini.enabled`
  Deploy-time Gemini route enable flag for the tenant.

How it overrides local settings:

- The control-plane YAML is host-authoritative only for the managed fields listed above.
- At deploy time, `scripts/sync_tenant_control_plane.py` applies those managed values ahead of the tenant start.
- This lets operators centralize shared overrides in one host-side file instead of hand-editing each tenant env file or changing container state by hand.
- Fields outside the managed list still belong to the tenant env file or other host config layers.

Use the tracked shape in `deploy/tenants/control-plane.example.yml` as the schema reference, but keep
the real file outside git on production hosts.

## 3. Per-Tenant Config

Source:

- `deploy/tenants/templates/tenant.env.example`

Purpose:

- tenant hostname and auth
- tenant enablement for `/terminal`, `/hermes`, `/codex`, `/claude`, `/gemini`
- tenant-specific provider keys
- optional per-tenant Tailscale settings

Typical examples:

- `TENANT_SLUG`
- `TENANT_HOSTNAME`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_BASIC_AUTH_USERNAME`
- `TERMINAL_BASIC_AUTH_PASSWORD`
- `GEMINI_API_KEY`
- `OPENROUTER_API_KEY`
- `TAILSCALE_ENABLED`

Keep tenant env files outside git.

`OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must match the exact public origin opened in the browser.
Example: `http://tenant-a.example.com:38080` when Traefik is exposed on port `38080`.
For vanilla native OpenClaw auth, the Control UI browser session should use HTTPS or localhost so
the device-identity flow has a secure context. Plain HTTP LAN hostnames are not a supported native
`/openclaw` path.

## 4. Standalone Gateway Config

Source:

- `services/rundiffusion-agents/.env.example`

Purpose:

- single-service `openclaw-gateway` deployment
- localhost, remote standalone hosts, or one-service platforms
- persistent `/data` volume without the multi-tenant orchestration layer

Typical examples:

- `OPENCLAW_ACCESS_MODE`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_ENABLED`
- `TERMINAL_BASIC_AUTH_USERNAME`
- `TERMINAL_BASIC_AUTH_PASSWORD`
- optional tool-specific API keys

For the recommended simple local path, bind the container to `localhost` and use an explicit
loopback allowlist such as `http://127.0.0.1:8080,http://localhost:8080`. If you later move the
browser origin to a non-loopback hostname, native `/openclaw` needs HTTPS or an intentional switch
to `trusted-proxy`.

## Tenant Registry

Tracked template:

- `deploy/tenants/tenants.example.yml`

Local ignored working file:

- `deploy/tenants/tenants.yml`

Purpose:

- map tenant slugs to hostnames
- map tenants to env files and data roots
- determine which tenants are enabled

The example file is intentionally public-safe and should ship with:

```yaml
tenants: []
```

The local `deploy/tenants/tenants.yml` file is ignored so operators can keep real tenant
metadata in the repo checkout without committing it.

Real tenant secrets still belong in external tenant env files, not in the registry.

## Rules Of Thumb

- Do not copy root vars into tenant env files.
- Use the host control-plane YAML for managed keys and startup-model overrides when that layer is enabled.
- Do not put tenant secrets in `deploy/tenants/tenants.example.yml`.
- Keep `deploy/tenants/tenants.yml` local and ignored.
- Do not commit `.env` or real tenant env files.
- Keep runtime state outside the repo checkout.
- Start from the example file for the layer you are actually using.
