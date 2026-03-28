# Cloudflare Access for OpenClaw

This workspace manages the Cloudflare side of the OpenClaw public portal:

- existing or newly created One-Time PIN identity provider
- self-hosted Access application
- allow policy scoped to one email address
- optional proxied DNS record for the OpenClaw hostname
- Cloudflare Origin CA certificate for the OpenClaw origin

The intended flow is:

1. Copy `terraform.tfvars.example` to a local `terraform.tfvars`
2. Fill in the Cloudflare account, zone, team name, hostname, and email
3. If the account already has a One-Time PIN provider, set its ID in `existing_one_time_pin_idp_id`
4. Run `terraform init`
5. Run `terraform plan`
6. Run `terraform apply`
7. Confirm the OpenClaw hostname shows a Cloudflare Access login prompt
8. Enable `cloudflare_access_enabled` and `cloudflare_origin_lockdown_enabled` in the Ansible inventory
9. Re-run Ansible provision and validation

The workspace is designed for local state. `terraform.tfvars` and state files
are intentionally ignored by Git.

On apply, Terraform also generates these local ignored files in the workspace:

- `openclaw-origin-ca.crt.pem`
- `openclaw-origin-ca.key.pem`

Those PEM files are meant to be consumed by the Ansible OpenClaw role when
`openclaw_tls_mode=cloudflare_origin_ca`.

For the Origin CA portion, the Cloudflare credential needs more than Access
permissions. Use an API token that includes
`Zone -> SSL and Certificates -> Edit` on the zone that owns the OpenClaw
hostname.

Cloudflare also documents a known failure mode where Origin CA creation returns
an access error even though the zone exists, because the member creating the
certificate does not have Cloudflare API Access enabled for that account.

Do not enable the origin lockdown role until the hostname is already proxied by
Cloudflare and the Access login flow is visible.

If `manage_openclaw_dns_record` is `true`, the API token also needs zone-level
permissions such as Zone Read and DNS Edit for the target zone.
