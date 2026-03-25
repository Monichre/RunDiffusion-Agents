# Multi-Tenant Host Deployment

This repo supports a shared-host, multi-tenant deployment model for RunDiffusion Agents.

This guide is for the repo-root **multi-tenant host stack only**.

If you want a single tenant, even on a remote host, do not use this guide. Use the standalone
package under `services/rundiffusion-agents/` and start with
[`docs/standalone-host-quickstart.md`](../docs/standalone-host-quickstart.md) instead.

The intended shape is:

- one shared host ingress layer
- one isolated `openclaw-gateway` container per tenant
- one tenant-specific hostname
- one tenant-specific data root on the host
- one tenant-specific env file outside git

Traefik and Cloudflare Tunnel are first-class in this repo, but the actual domain, tunnel, and
credentials are always user-supplied configuration.

## Deployment Matrix

- `single tenant local or remote`
  Use the standalone package under `services/rundiffusion-agents/`. This guide does not cover that
  path.
- `multi-tenant local/LAN over HTTP`
  Use this guide when you want the shared-host stack on a private network. `/dashboard`,
  `/terminal`, and sibling tools are fine over plain HTTP, but vanilla native `/openclaw` still
  requires HTTPS or `localhost`.
- `multi-tenant direct`
  Use this guide when the host or VM is exposed directly with proper DNS and HTTPS.
- `multi-tenant cloudflare`
  Use this guide when `cloudflared` publishes Traefik and provides the HTTPS browser origin.

TLS automation for private-hostname LAN installs is outside the scope of this release.

## Ingress Modes

This host stack supports three ingress patterns:

- `local`
  Keep Traefik private for localhost, LAN, or internal-network access. Good for families, teams,
  and home-lab installs. The host stack itself works on HTTP, but native `/openclaw` on a plain
  HTTP LAN hostname is not a supported vanilla device-auth path.
- `direct`
  Expose Traefik directly on the server or VM IP and point your own domains or subdomains at it.
- `cloudflare`
  Keep Traefik bound locally and publish it through `cloudflared`.

Recommended root env shape for each mode:

```env
# Local-only or LAN access
INGRESS_MODE=local
TRAEFIK_BIND_ADDRESS=127.0.0.1

# Direct host exposure
INGRESS_MODE=direct
TRAEFIK_BIND_ADDRESS=0.0.0.0

# Cloudflare Tunnel
INGRESS_MODE=cloudflare
TRAEFIK_BIND_ADDRESS=127.0.0.1
```

Multi-tenant routing still relies on hostnames. For local or direct installs, point those
hostnames at the Traefik host through public DNS, private DNS, or hosts-file entries. Bare-IP
access is fine for a single tenant or a quick internal rollout test, but hostname routing is the
normal multi-tenant path.

If you need native `/openclaw` for operators over the network, use HTTPS. The HTTP/LAN case is
best understood as host-stack access for the sibling operator routes, not as the recommended native
OpenClaw security model.

## LAN Expectations

Use `INGRESS_MODE=local` when you want several tenant instances available on a private network.

What works cleanly over plain HTTP on a LAN:

- `/dashboard`
- `/terminal`
- `/filebrowser`
- `/hermes`
- `/codex`
- `/claude`
- `/gemini`

What needs a different expectation:

- native `/openclaw` on a non-loopback HTTP hostname is not a supported vanilla device-auth path
- if remote LAN users need native `/openclaw`, put HTTPS in front of the tenant hostname
- if you do not want HTTPS, keep native `/openclaw` on localhost or intentionally use
  `OPENCLAW_ACCESS_MODE=trusted-proxy`

This means the multi-tenant LAN story in this repo is real, but it is not "full native OpenClaw
everywhere over HTTP." Plan your operator workflow around that.

## Architecture

- Shared ingress
  - `traefik` in Docker Compose
  - optional `cloudflared` managed on the host
- Tenant isolation
  - one Docker Compose project per tenant
  - one host data path per tenant
  - one tenant env file per tenant
  - one release history per tenant for rollback
- Shared app surface inside every tenant
  - `/openclaw`
  - `/dashboard`
  - `/filebrowser`
  - `/terminal`
  - `/hermes`
  - `/codex`
  - `/claude`
  - `/gemini`

## First-Time Setup

1. Clone the repo onto the host you want to use.
2. Copy the root env template:

```bash
cp .env.example .env
```

3. Edit `.env` with your domain, host paths, ingress settings, and image settings.
4. Create the local tenant registry from the template:

```bash
cp deploy/tenants/tenants.example.yml deploy/tenants/tenants.yml
```

If you skip this step, the deploy scripts will create `deploy/tenants/tenants.yml`
automatically from the example the first time they need it.

### Required Host Tooling

The shared-host deployment scripts depend on host CLI tools outside Docker:

- `bash`
- `curl`
- `docker`
- `jq`
- `yq`
- `openssl`

Recommended:

- `python3` for validation and migration helpers

Platform notes:

- macOS and Linux are supported directly.
- Windows should use WSL2 for this repo and for running the `scripts/*.sh` commands.

Example install commands:

macOS:

```bash
brew install jq yq openssl
brew install --cask docker
```

Ubuntu or Debian:

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 curl jq yq openssl python3
```

Fedora:

```bash
sudo dnf install -y docker-cli docker-compose curl jq yq openssl python3
```

Arch Linux:

```bash
sudo pacman -S --needed docker docker-compose curl jq yq openssl python
```

Windows:

1. Install Docker Desktop.
2. Enable WSL2 integration for your Linux distro.
3. Install the Linux packages above inside WSL.

5. If you are on macOS and want the local helper flow, run:

```bash
./scripts/bootstrap-mac-mini.sh
```

6. If you choose `INGRESS_MODE=cloudflare`, create a Cloudflare Tunnel and place its credentials
   JSON on the host.
7. Create your first tenant:

```bash
./scripts/create-tenant.sh tenant-a "Tenant A"
```

8. Deploy shared ingress and all enabled tenants:

```bash
./scripts/deploy.sh
```

9. Verify health:

```bash
./scripts/status.sh
./scripts/smoke-test.sh --all
```

## Recommended Host Layout

Keep live runtime state in a host-managed tree outside the repo checkout.

Example layout:

```text
/srv/rundiffusion-agents/
  data/
    tenants/<slug>/
    backups/
    releases/
    traefik/
    cloudflared/
  secrets/
    tenants/<slug>.env
```

That maps cleanly to the root env contract:

```env
DATA_ROOT=/srv/rundiffusion-agents/data
TENANT_ENV_ROOT=/srv/rundiffusion-agents/secrets/tenants
```

If you already have older repo-local state in `.data/` or `deploy/tenants/env/`, update `.env`
first and then run:

```bash
./scripts/migrate-host-storage.sh
```

## Required Environment And Secrets

Root `.env` owns shared host and ingress settings such as:

- `BASE_DOMAIN`
- `INGRESS_MODE`
- `PUBLIC_URL_SCHEME`
- `DATA_ROOT`
- `TENANT_ENV_ROOT`
- `TRAEFIK_BIND_ADDRESS`
- `TRAEFIK_HTTP_PORT`
- `TRAEFIK_NETWORK`
- `CLOUDFLARE_HOSTNAME_MODE`
- `CLOUDFLARE_TUNNEL_ID`
- `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE`
- `COMPOSE_PROJECT_NAME`
- `OPENCLAW_VERSION`
- `TENANT_CONTAINER_SECURITY_PROFILE`

Each tenant env file owns tenant-specific values such as:

- `TENANT_SLUG`
- `TENANT_HOSTNAME`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_BASIC_AUTH_USERNAME`
- `TERMINAL_BASIC_AUTH_PASSWORD`
- optional `TAILSCALE_ENABLED`, `TAILSCALE_AUTHKEY`, and `TAILSCALE_HOSTNAME`
- optional provider keys only for that tenant

`OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` must be the exact public browser origin for `/openclaw`,
including `:${TRAEFIK_HTTP_PORT}` when Traefik is exposed on a non-default port such as `38080`.
For vanilla native OpenClaw auth, prefer an HTTPS browser origin or localhost so device approval
works in a secure context. Plain HTTP LAN hostnames are not a supported native `/openclaw` path.

See [docs/configuration.md](../docs/configuration.md) for the full configuration matrix.
Use the host control-plane YAML for tenant-specific managed overrides such as `openclawVersion`.
The precedence and ownership rules live in [docs/configuration.md](../docs/configuration.md).

## Tenant Container Security Profile

`TENANT_CONTAINER_SECURITY_PROFILE` controls the Docker security settings for each tenant's
`openclaw-gateway` container.

Accepted values:

- `restricted`
  Use the default Docker profile.
- `tool-userns`
  Add `SYS_ADMIN` plus unconfined seccomp/apparmor so bundled CLIs can create the namespaces they
  need.
- `privileged`
  Use `privileged: true` only as a fallback.

Recommended escalation path:

1. Set `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns`
2. Redeploy the affected tenant
3. Validate inside the container with `docker exec <container> unshare -U true`
4. Escalate to `privileged` only if that still fails

## Per-Tenant Tailscale

Tailscale is optional and enabled per tenant.

Add the following to the tenant env file when you want it:

```env
TAILSCALE_ENABLED=1
TAILSCALE_AUTHKEY=
TAILSCALE_HOSTNAME=
```

When enabled, the tenant gets:

- `/dev/net/tun`
- `NET_ADMIN` and `NET_RAW`
- a persistent `${DATA_ROOT}/tenants/<slug>/tailscale` mount at `/var/lib/tailscale`

## Cloudflare Tunnel Setup

Cloudflare Tunnel is optional. Use this section only when `INGRESS_MODE=cloudflare`.

Typical flow:

1. Create the named tunnel in Cloudflare.
2. Download the tunnel credentials JSON locally.
3. Render the local config from the tenant registry:

```bash
./scripts/render-cloudflared-config.sh
```

4. Create a wildcard DNS route for your base domain:

```bash
cloudflared tunnel route dns <tunnel-name> '*.example.com'
```

5. Optionally adapt [config.yml.example](cloudflared/config.yml.example).
6. On macOS hosts, you can install the launch agent with:

```bash
./scripts/install-cloudflared-launchd.sh
```

## Day-To-Day Operations

Create a tenant:

```bash
./scripts/create-tenant.sh tenant-a "Tenant A"
```

Update tenant metadata:

```bash
./scripts/update-tenant.sh tenant-a --hostname tenant-a.example.com
./scripts/update-tenant.sh tenant-a --disable
./scripts/update-tenant.sh tenant-a --enable
```

List tenants:

```bash
./scripts/list-tenants.sh
```

Deploy one tenant:

```bash
./scripts/deploy.sh --tenant tenant-a
```

See [docs/tenant-operations.md](../docs/tenant-operations.md) for the full operator runbook.
