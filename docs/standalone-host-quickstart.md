# Standalone Host Quickstart

Use this guide for the single-tenant package under `services/rundiffusion-agents`.

This is the right path when you want:

- local single tenant on `localhost`
- remote single tenant on one VM or one bare-metal host
- remote single tenant published through Cloudflare Tunnel

If you need multiple tenant hostnames behind shared ingress, stop and use the repo-root
multi-tenant host stack instead.

> Use at your own risk. This is bleeding-edge operator software. You are
> responsible for credentials, access control, backups, data protection,
> third-party API usage, and the consequences of any deployment or configuration
> mistake. Test in a non-production environment first and read
> [`DISCLAIMER.md`](../DISCLAIMER.md).

## Prerequisites

- Docker with Compose support
- this repo checked out on the host that will run the container

## Quick Start

From the repo root:

```bash
cd services/rundiffusion-agents
cp .env.example .env
```

Set at least:

- `OPENCLAW_ACCESS_MODE=native`
- `OPENCLAW_GATEWAY_TOKEN=<long-random-secret>`
- `TERMINAL_BASIC_AUTH_USERNAME=<username>`
- `TERMINAL_BASIC_AUTH_PASSWORD=<strong-password>`
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=<exact browser origin>`

Then start the package:

```bash
docker compose up -d --build
```

Useful day-two commands:

```bash
docker compose logs -f
docker compose down
```

## Compose Helper Vars

The standalone `.env` file now includes Compose helper vars for host-side packaging:

- `STANDALONE_BIND_ADDRESS`
- `STANDALONE_PUBLIC_PORT`
- `STANDALONE_CONTAINER_NAME`
- `STANDALONE_DATA_VOLUME`

Use them when you want to move the listener off loopback, pick a different public port, or choose
a different container or volume name. They are helper vars for Docker Compose, not part of the
gateway runtime contract.

## Local Single Tenant

Recommended values:

```env
STANDALONE_BIND_ADDRESS=127.0.0.1
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080
```

Open:

- `http://127.0.0.1:8080/dashboard`
- `http://127.0.0.1:8080/openclaw`

This is the clean vanilla native `/openclaw` path because the browser origin stays on `localhost`.

## Remote Single Tenant With Direct DNS + HTTPS

Use the same package under `services/rundiffusion-agents`.

Typical shape:

```env
STANDALONE_BIND_ADDRESS=0.0.0.0
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://agent.example.com
```

Notes:

- point your DNS name at the host
- terminate TLS with your own load balancer, reverse proxy, or external edge
- for vanilla native `/openclaw`, the browser origin should stay HTTPS
- plain HTTP non-loopback hostnames are not a supported vanilla native `/openclaw` path

## Remote Single Tenant With Cloudflare Tunnel

Use the same standalone package when you want one service but prefer Cloudflare to publish it.

Typical shape:

```env
STANDALONE_BIND_ADDRESS=127.0.0.1
STANDALONE_PUBLIC_PORT=8080
OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS=https://agent.example.com
```

Typical host flow:

1. Start the standalone package locally with `docker compose up -d --build`.
2. Create a Cloudflare Tunnel outside this repo.
3. Route `agent.example.com` through that tunnel to `http://127.0.0.1:8080`.
4. Open the HTTPS hostname and confirm it matches `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`.

This repo does not ship a dedicated single-tenant `cloudflared` sidecar. Treat the tunnel as
host-managed infrastructure for this deployment shape.

## OpenClaw Expectations

- `localhost` is the clean native path without HTTPS
- non-loopback hostnames should use HTTPS for vanilla native `/openclaw`
- if `/openclaw` shows `origin not allowed`, fix `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS`
- if `/openclaw` shows a secure-context or device-identity error, move the browser origin to HTTPS or localhost

## When To Switch Tracks

Move to the multi-tenant host stack when you need:

- more than one tenant hostname
- shared Traefik ingress
- per-tenant env files and tenant registry entries
- repo-root deploy scripts such as `./scripts/create-tenant.sh` and `./scripts/deploy.sh`

See [Multi-Tenant Host Deployment](../deploy/README.md) for that path.
