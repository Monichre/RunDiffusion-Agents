# Tenant Operations

This is the day-to-day runbook for the multi-tenant host stack.

## LAN Expectations

For a few tenant instances on a private network, use `INGRESS_MODE=local`.

- `/dashboard`, `/terminal`, `/filebrowser`, `/hermes`, `/codex`, `/claude`, and `/gemini` can be
  served over plain HTTP on the LAN.
- Native `/openclaw` is not a supported vanilla path on a non-loopback HTTP hostname.
- If operators on other LAN devices need native `/openclaw`, use HTTPS for that tenant hostname.
- If you do not want HTTPS, keep native `/openclaw` on localhost or intentionally switch the
  tenant to `OPENCLAW_ACCESS_MODE=trusted-proxy`.

## Create A Tenant

1. Confirm `.env` is present and matches `.env.example`
2. Create the tenant:

```bash
./scripts/create-tenant.sh tenant-a "Tenant A" tenant-a.example.com
```

3. Edit the generated tenant env file under `TENANT_ENV_ROOT`
   Confirm `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` matches the exact browser origin, including the
   Traefik port when it is not `80` or `443`. For vanilla native `/openclaw`, use HTTPS unless
   you are on `localhost`. Plain HTTP LAN hostnames are not a supported native path.
4. Deploy the tenant:

```bash
./scripts/deploy.sh --tenant tenant-a
```

5. Verify it:

```bash
./scripts/status.sh
./scripts/smoke-test.sh --tenant tenant-a
```

## Update A Tenant

Update registry metadata:

```bash
./scripts/update-tenant.sh tenant-a --display-name "Tenant A Updated"
./scripts/update-tenant.sh tenant-a --hostname tenant-a.example.com
./scripts/update-tenant.sh tenant-a --disable
./scripts/update-tenant.sh tenant-a --enable
```

Update tenant secrets or provider keys:

1. Edit `${TENANT_ENV_ROOT}/tenant-a.env`
   If `/openclaw` shows `origin not allowed`, update `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS` to the
   exact public origin you open in the browser, including the port when present.
   If native `/openclaw` shows a secure-context or device-identity error, move that browser origin
   to HTTPS or use the standalone single-tenant flow instead.
2. Redeploy:

```bash
./scripts/deploy.sh --tenant tenant-a
```

## Deploy, Roll Back, Stop, Delete

Deploy all enabled tenants:

```bash
./scripts/deploy.sh
```

Deploy shared ingress only:

```bash
./scripts/deploy.sh --shared-only
```

Roll back a tenant:

```bash
./scripts/rollback.sh --tenant tenant-a
```

Stop a tenant:

```bash
./scripts/stop-tenant.sh tenant-a
```

Delete a tenant but keep runtime data:

```bash
./scripts/delete-tenant.sh tenant-a
```

Delete a tenant and purge data:

```bash
./scripts/delete-tenant.sh tenant-a --purge
```

## Health Checks

List tenants:

```bash
./scripts/list-tenants.sh
```

Shared status:

```bash
./scripts/status.sh
```

Smoke test one tenant:

```bash
./scripts/smoke-test.sh --tenant tenant-a
```

Smoke test all enabled tenants:

```bash
./scripts/smoke-test.sh --all
```

## Safety Rules

- Keep root `.env` and tenant env files outside public version control
- Keep tenant runtime data outside the repo checkout
- Re-render shared ingress by running the normal deploy scripts after tenant add/delete/hostname changes
- Use `TENANT_CONTAINER_SECURITY_PROFILE=tool-userns` before escalating to `privileged`
- Treat Cloudflare tunnel IDs, credentials files, API keys, and tenant auth tokens as secrets
