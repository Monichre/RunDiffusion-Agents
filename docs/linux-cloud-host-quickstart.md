# Linux Host Quickstart

Use this guide when you want to run the **multi-tenant host stack** on a Linux server, cloud VM, or
bare-metal host.

This guide assumes:

- one Linux host
- Docker on the host
- the repo checked out on that host
- one or more tenant containers behind Traefik

If you want a single-tenant install, whether local or remote, use the standalone package under
`services/rundiffusion-agents/` and start with
[`docs/standalone-host-quickstart.md`](./standalone-host-quickstart.md) instead.

> Use at your own risk. This stack is intended for capable operators managing
> Docker, ingress, secrets, and tenant isolation. You are responsible for
> protecting credentials and data, complying with third-party service terms, and
> validating the deployment before putting it anywhere near production. Read
> [`DISCLAIMER.md`](../DISCLAIMER.md).

## Choose Your Public Path

- `INGRESS_MODE=cloudflare`
  Recommended public path. Cloudflare Tunnel gives the browser an HTTPS origin without exposing
  Traefik directly.
- `INGRESS_MODE=direct`
  Use this only when you already have a plan for DNS and HTTPS in front of the host. This repo does
  not automate public TLS issuance in the current release.
- `INGRESS_MODE=local`
  Good for private networks, VPNs, or internal-only access. Plain HTTP is fine for the sibling
  operator routes, but native `/openclaw` still needs HTTPS or localhost.

## Host Prerequisites

Install:

- Docker Engine or Docker CE
- `bash`
- `curl`
- `jq`
- `yq`
- `openssl`
- `python3`

Ubuntu or Debian example:

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 curl jq yq openssl python3
```

## Provider-Neutral Host Notes

These checks apply on any Linux cloud host or bare-metal server:

- reserve a stable public IP if the host will be public
- allow SSH only from trusted admin IPs
- for `INGRESS_MODE=direct`, allow inbound traffic only to the port you intentionally expose for
  Traefik
- for `INGRESS_MODE=cloudflare`, you usually do not need public inbound traffic to Traefik at all;
  outbound `443` is the critical path for `cloudflared`
- keep the data and secret roots on attached persistent storage, not inside the repo checkout

Examples of hosts this guide is meant to cover:

- Google Cloud
- AWS
- Azure
- DigitalOcean
- Hetzner
- on-prem bare-metal Linux

Keep host storage outside the repo checkout. Recommended:

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

## Root Host Setup

From the repo root:

```bash
cp .env.example .env
cp deploy/tenants/tenants.example.yml deploy/tenants/tenants.yml
```

Set at least:

```env
BASE_DOMAIN=agents.example.com
DATA_ROOT=/srv/rundiffusion-agents/data
TENANT_ENV_ROOT=/srv/rundiffusion-agents/secrets/tenants
```

### Direct Host Exposure

Use this only when you already have HTTPS handled outside the repo.

Example root env shape:

```env
INGRESS_MODE=direct
PUBLIC_URL_SCHEME=https
TRAEFIK_BIND_ADDRESS=0.0.0.0
TRAEFIK_HTTP_PORT=80
```

Notes:

- point DNS at the host
- terminate TLS with your own load balancer, reverse proxy, or other external edge
- for vanilla native `/openclaw`, the browser origin should still be HTTPS

### Cloudflare Tunnel

This is the recommended public path for this release.

Example root env shape:

```env
INGRESS_MODE=cloudflare
PUBLIC_URL_SCHEME=https
TRAEFIK_BIND_ADDRESS=127.0.0.1
TRAEFIK_HTTP_PORT=38080
CLOUDFLARE_HOSTNAME_MODE=wildcard
CLOUDFLARE_TUNNEL_ID=<tunnel-id>
CLOUDFLARE_TUNNEL_CREDENTIALS_FILE=/srv/rundiffusion-agents/data/cloudflared/tunnel.json
```

Typical flow:

1. Create the named tunnel in Cloudflare.
2. Download the tunnel credentials JSON to the host path named by
   `CLOUDFLARE_TUNNEL_CREDENTIALS_FILE`.
3. Render the config:

```bash
./scripts/render-cloudflared-config.sh
```

4. Create the wildcard DNS route:

```bash
cloudflared tunnel route dns <tunnel-name> '*.example.com'
```

5. Start `cloudflared` on Linux against the rendered config:

```bash
cloudflared --config /srv/rundiffusion-agents/data/cloudflared/config.yml tunnel run
```

6. After manual validation, manage that command under your preferred Linux service manager.

Repo note:

- the repo ships a macOS launchd helper for Cloudflare Tunnel
- it does **not** ship a Linux systemd helper in this release

## Create The First Tenant

```bash
./scripts/create-tenant.sh tenant-a "Tenant A"
```

Then edit `${TENANT_ENV_ROOT}/tenant-a.env`.

Important fields:

- `TENANT_HOSTNAME`
- `OPENCLAW_GATEWAY_TOKEN`
- `TERMINAL_BASIC_AUTH_USERNAME`
- `TERMINAL_BASIC_AUTH_PASSWORD`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`

For native OpenClaw:

- the allowlist must match the exact browser origin
- include the port when Traefik is not on `80` or `443`
- use HTTPS for public or remote-operator access

Examples:

```env
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://tenant-a.example.com
```

```env
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://tenant-a.example.com:8443
```

## Deploy

```bash
./scripts/deploy.sh
```

Or for one tenant only:

```bash
./scripts/deploy.sh --tenant tenant-a
```

## Verify

```bash
./scripts/status.sh
./scripts/smoke-test.sh --all
```

Check:

- Traefik is healthy
- each tenant is `running/healthy`
- the hostname resolves the way you expect
- `/dashboard` loads
- `/openclaw` has the exact origin allowlisted

## OpenClaw Expectations

- `localhost` is the clean native path without HTTPS
- `cloudflare` gives you the expected HTTPS browser origin
- `direct` is fine only when you already have HTTPS handled outside the repo
- plain HTTP LAN or public hostnames are not a supported vanilla native `/openclaw` path

If `/openclaw` shows:

- `origin not allowed`
  fix `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- `control ui requires device identity (use HTTPS or localhost secure context)`
  move the browser origin to HTTPS or localhost
