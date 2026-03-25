# Deployment Matrix

Use this chooser first. It maps the four supported deployment scenarios to the right package,
environment template, bundled skill, and command path.

## Package Families

- `services/rundiffusion-agents`
  Single-tenant package for local and remote one-service installs.
- repo root host stack
  Multi-tenant package for local and remote shared-host installs with Traefik.

## Scenario Matrix

| Scenario | Package | Env template | Bundled skill | Browser origin expectation | First commands |
| --- | --- | --- | --- | --- | --- |
| Local single tenant | `services/rundiffusion-agents` | `services/rundiffusion-agents/.env.example` | [`$rundiffusion-standalone-agent-manager`](../skills/rundiffusion-standalone-agent-manager/SKILL.md) | `localhost` is the clean native `/openclaw` path | `cd services/rundiffusion-agents`, `cp .env.example .env`, `docker compose up -d --build` |
| Remote single tenant | `services/rundiffusion-agents` | `services/rundiffusion-agents/.env.example` | [`$rundiffusion-standalone-agent-manager`](../skills/rundiffusion-standalone-agent-manager/SKILL.md) | Use HTTPS or Cloudflare Tunnel for native `/openclaw` on a hostname | `cd services/rundiffusion-agents`, `cp .env.example .env`, `docker compose up -d --build` |
| Local multi tenant | repo root host stack | `.env.example` plus generated tenant env file | [`$rundiffusion-host-agent-manager`](../skills/rundiffusion-host-agent-manager/SKILL.md) | Hostnames still route tenants; plain HTTP LAN is fine for sibling tools but not vanilla native `/openclaw` | `cp .env.example .env`, `./scripts/create-tenant.sh`, `./scripts/deploy.sh` |
| Remote multi tenant | repo root host stack | `.env.example` plus generated tenant env file | [`$rundiffusion-host-agent-manager`](../skills/rundiffusion-host-agent-manager/SKILL.md) | Use Cloudflare Tunnel or your own DNS + HTTPS mapping | `cp .env.example .env`, `./scripts/create-tenant.sh`, `./scripts/deploy.sh` |

## Skill Routing

The bundled skills are expected to inspect the repo and env state before asking questions.

Inspection order:

1. current working directory
2. root `.env.example`
3. standalone `services/rundiffusion-agents/.env.example`
4. root `.env`, if present
5. standalone `services/rundiffusion-agents/.env`, if present
6. tenant registry presence
7. `INGRESS_MODE`
8. Cloudflare tunnel vars
9. hostname and allowed-origin values
10. whether the user is operating from repo root or `services/rundiffusion-agents`

Expected inference:

- standalone vs multi-tenant
- local vs remote intent
- Cloudflare vs direct DNS/HTTPS
- which env example applies
- which package and command path apply

Ask the user only when ambiguity remains after inspection, such as:

- a fresh checkout with no env files and no clear target
- conflicting standalone and multi-tenant state
- remote intent is obvious but Cloudflare vs direct DNS/HTTPS is still unclear

When the wrong skill is invoked, it should say so plainly and route to the correct package instead
of guessing.

## Next Docs

- [Standalone Host Quickstart](./standalone-host-quickstart.md)
- [Multi-Tenant Host Deployment](../deploy/README.md)
- [Configuration Layers](./configuration.md)
