# Environment Contract

## Root Env

Read [`../../.env.example`](../../.env.example) first. It defines the shared host contract for:

- tenant storage paths
- Traefik and Cloudflare routing
- image build and deploy behavior
- tenant resource limits
- release and backup roots

Read [`../../.env`](../../.env) second. It contains the actual values for this host.

The current root env keys are:

- `COMPOSE_PROJECT_NAME`
- `BASE_DOMAIN`
- `INGRESS_MODE`
- `PUBLIC_URL_SCHEME`
- `TRAEFIK_BIND_ADDRESS`
- `CLOUDFLARE_HOSTNAME_MODE`
- `DATA_ROOT`
- `TENANT_ENV_ROOT`
- `TRAEFIK_HTTP_PORT`
- `TRAEFIK_NETWORK`
- `TRAEFIK_LOG_LEVEL`
- `CLOUDFLARE_TUNNEL_ID`
- `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE`
- `CLOUDFLARE_TUNNEL_METRICS`
- `CLOUDFLARED_LAUNCHD_LABEL`
- `DEPLOY_MODE`
- `AUTO_ROLLBACK`
- `IMAGE_REPOSITORY`
- `OPENCLAW_VERSION`
- `GATEWAY_IMAGE_TAG`
- `TENANT_MEMORY_RESERVATION`
- `TENANT_MEMORY_LIMIT`
- `TENANT_PIDS_LIMIT`
- `TENANT_CONTAINER_SECURITY_PROFILE`
- `MAX_ALWAYS_ON_TENANTS`
- `BACKUP_ROOT`
- `RELEASE_ROOT`

Blank values in `.env` are not automatically errors. `OPENCLAW_VERSION`, `GATEWAY_IMAGE_TAG`, `BACKUP_ROOT`, and `RELEASE_ROOT` may be intentionally blank because helper scripts derive defaults.

`OPENCLAW_VERSION` is the shared default. Tenant-specific overrides belong in the host control-plane
YAML as `openclawVersion`. See [`../../docs/configuration.md`](../../docs/configuration.md) for precedence and ownership details.

`TENANT_CONTAINER_SECURITY_PROFILE` controls the Docker security profile for each tenant's
single `openclaw-gateway` container. Use:

- `restricted` for the current locked-down Docker defaults
- `tool-userns` to add `SYS_ADMIN` plus unconfined seccomp/apparmor for CLI tools that need Linux namespaces
- `privileged` only as a fallback if `tool-userns` still fails on a host

This applies to every sibling tool route inside the tenant container, including `/codex`,
`/claude`, `/gemini`, and future CLI routes added to `openclaw-gateway`. It does not affect
unrelated services outside that tenant container.

Recommended host rollout:

1. Set `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns`.
2. Redeploy the affected tenant.
3. Run `unshare -U true` inside the container.
4. Escalate to `privileged` only if that still fails.

## Tenant Env

The tenant env template lives at [`../../deploy/tenants/templates/tenant.env.example`](../../deploy/tenants/templates/tenant.env.example).

The real tenant env files live under `TENANT_ENV_ROOT`, which should point to a host-managed directory outside git such as `/srv/rundiffusion-agents/secrets/tenants`.

Tenant env files hold only tenant-specific values such as:

- `TENANT_SLUG`
- `TENANT_HOSTNAME`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- `OPENCLAW_ACCESS_MODE`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_ENABLED`
- `TERMINAL_BASIC_AUTH_USERNAME`
- `TERMINAL_BASIC_AUTH_PASSWORD`
- `HERMES_ENABLED`
- `CODEX_ENABLED`
- `CLAUDE_ENABLED`
- `GEMINI_ENABLED`
- optional `TAILSCALE_ENABLED`
- optional `TAILSCALE_AUTHKEY`
- optional `TAILSCALE_HOSTNAME`
- provider credentials

`OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must be the exact browser origin for the Control UI,
including `:${TRAEFIK_HTTP_PORT}` when Traefik is not on `80` or `443`.
For the vanilla native auth flow, the browser origin should be HTTPS or localhost so device
approval runs in a secure context. Plain HTTP LAN hostnames are not a supported native `/openclaw`
path.

## How Vars Reach Docker

Do not duplicate root vars into tenant env files.

The effective deploy flow is:

1. `scripts/lib/common.sh` loads the root `.env`.
2. Registry values in `deploy/tenants/tenants.yml` are expanded with root vars such as `${DATA_ROOT}` and `${TENANT_ENV_ROOT}`.
3. `compose_tenant` exports derived values such as:
   - `TENANT_SLUG`
   - `TENANT_HOSTNAME`
   - `TENANT_DATA_ROOT`
   - `TENANT_ENV_FILE`
   - `OPENCLAW_IMAGE`
4. `deploy/tenant-stack.compose.yml` uses those derived values plus root resource limits.
5. The container receives the tenant env file through `env_file`.
6. If `TAILSCALE_ENABLED=1`, `compose_tenant` adds a runtime override for `/dev/net/tun`,
   `NET_ADMIN`, `NET_RAW`, and a tenant-scoped bind mount for `/var/lib/tailscale`.

This means "propagating vars" usually means:

- ensure the root `.env` is complete and correct
- ensure the tenant registry entry points at the right env file and data root
- ensure the tenant env file contains the tenant-specific values

For OpenClaw version selection, keep the shared default in root `.env`, use control-plane
`openclawVersion` only when one tenant must diverge, and do not copy it into tenant env files.

Not:

- copying every root var into every tenant env file

Recommended host layout:

- `${DATA_ROOT}` -> `/srv/rundiffusion-agents/data`
- `${TENANT_ENV_ROOT}` -> `/srv/rundiffusion-agents/secrets/tenants`
- tenant runtime data -> `${DATA_ROOT}/tenants/<slug>`
- tenant env files -> `${TENANT_ENV_ROOT}/<slug>.env`

## Safe Mutation Order

When preparing a new or changed tenant:

1. Validate root env against `.env.example`.
2. Confirm registry entry and expanded paths.
3. Confirm or edit tenant env values.
4. Deploy.
5. Smoke-test.
