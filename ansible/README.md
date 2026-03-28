# Ansible Operator Guide

This directory contains the Ansible workspace used to reset, provision, and
validate the VPS.

All commands below assume you are running from `ansible/`, so that the local
`ansible.cfg` file is picked up with the expected inventory, roles path, and
collections path.

----

## Prerequisites

From the repository root:

```bash
python3 -m venv .venv
. .venv/bin/activate
cd ansible
python3 -m pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

This repository keeps SSH host key checking enabled. Before the first run
against a new server, record its host key in `~/.ssh/known_hosts`:

```bash
ssh-keyscan -H REPLACE_ME_HOST >> ~/.ssh/known_hosts
```

----

## Inventory model

The inventory is split on purpose:

- `inventories/example/` is the committed baseline with placeholders only
- `inventories/personal/` is the untracked working copy for a real host
- host metadata and vault data belong in `inventories/personal/`

Create the local working inventory:

```bash
cp -R inventories/example inventories/personal
cp inventories/example/group_vars/all/vault.example.yml inventories/personal/group_vars/all/vault.yml
ansible-vault encrypt inventories/personal/group_vars/all/vault.yml
```

At minimum, edit:

- `inventories/personal/hosts.yml`
- `inventories/personal/group_vars/all/main.yml`
- `inventories/personal/group_vars/all/vault.yml`

Keep the boundary clean:

- commit placeholders and reusable defaults
- keep live IPs, domains, tokens, vault files, and contact details out of Git

Quick check before pushing:

```bash
git status --short
git check-ignore ansible/.vault_pass \
  inventories/personal/hosts.yml \
  inventories/personal/group_vars/all/main.yml \
  inventories/personal/group_vars/all/vault.yml \
  ../terraform/cloudflare-access/terraform.tfvars \
  ../terraform/cloudflare-access/openclaw-origin-ca.crt.pem \
  ../terraform/cloudflare-access/openclaw-origin-ca.key.pem
```

----

## Commands

Reset a host:

```bash
. ../.venv/bin/activate
ansible-playbook -i inventories/personal/hosts.yml playbooks/reset.yml
```

Provision a host:

```bash
. ../.venv/bin/activate
ansible-playbook -i inventories/personal/hosts.yml --ask-vault-pass playbooks/provision.yml
```

Validate a host:

```bash
. ../.venv/bin/activate
ansible-playbook -i inventories/personal/hosts.yml --ask-vault-pass playbooks/validate.yml
```

Run static checks before publishing or refactoring shared automation:

```bash
. ../.venv/bin/activate
ansible-playbook --syntax-check -i inventories/example/hosts.yml playbooks/reset.yml
ansible-playbook --syntax-check -i inventories/example/hosts.yml playbooks/provision.yml
ansible-playbook --syntax-check -i inventories/example/hosts.yml playbooks/validate.yml
ansible-lint
```

What they do:

- `reset.yml` removes installed K3s state and related host artifacts
- `provision.yml` prepares the host, installs K3s, and applies optional cluster services
- `validate.yml` checks host state, cluster health, certificates, and deployed services

----

## Feature flags

- `ssh_hardening_enabled`: manage an `sshd_config.d` hardening drop-in
- `ssh_allowed_users`: limit SSH logins to the named local accounts
- `ssh_password_auth_enabled`: keep password login on or off
- `ssh_root_login`: set the `PermitRootLogin` mode
- `ssh_max_auth_tries`, `ssh_max_sessions`, `ssh_max_startups`: tighten SSH daemon thresholds
- `fail2ban_enabled`: install and run fail2ban for the sshd jail
- `cert_manager_enabled`: install cert-manager when `true`
- `acme_dns_provider`: set to `cloudflare` to enable Cloudflare-backed DNS-01 issuers
- `cloudflare_access_enabled`: expect the public hostname to be protected by Cloudflare Access
- `cloudflare_origin_lockdown_enabled`: allow `80/tcp` and `443/tcp` only from Cloudflare IP ranges
- `cloudflare_ips_v4_url` and `cloudflare_ips_v6_url`: source URLs for Cloudflare origin allowlists
- `tailscale_enabled`: install and join Tailscale on the VPS
- `tailscale_private_ssh_enabled`: move SSH behind `tailscale0`
- `tailscale_private_k3s_api_enabled`: move the K3s API behind `tailscale0`
- `tailscale_k3s_api_host`: optional MagicDNS hostname to use in the admin kubeconfig instead of the node's Tailscale IP
- `validation_run_tls_smoke`: issue a temporary ACME smoke certificate during validation when `true`
- `openclaw_enabled`: deploy OpenClaw into the cluster when `true`

The example inventory keeps DNS automation off by default. OpenClaw is enabled
in the example inventory, but its optional web and WhatsApp features remain off
until you turn them on explicitly.

----

## OpenClaw

When `openclaw_enabled: true`, the provision playbook applies a repo-managed
manifest bundle into the `openclaw` namespace. The deployment is exposed through
Traefik and can either request a certificate from the configured ClusterIssuer
or load a Cloudflare Origin CA certificate from local PEM files.

Set these non-secret vars in `inventories/personal/group_vars/all/main.yml`:

- `openclaw_namespace`
- `openclaw_image`
- `openclaw_host`
- `openclaw_storage_size`
- `openclaw_gateway_bind`
- `openclaw_gateway_port`
- `openclaw_gateway_trusted_proxies`
- `openclaw_gateway_allow_real_ip_fallback`
- `openclaw_model_primary`
- `openclaw_clusterissuer`
- `openclaw_tls_mode`
- `openclaw_tls_secret_name`
- `openclaw_origin_ca_certificate_path`
- `openclaw_origin_ca_private_key_path`
- `openclaw_web_enabled`
- `openclaw_web_heartbeat_seconds`
- `openclaw_whatsapp_enabled`
- `openclaw_whatsapp_account_id`
- `openclaw_whatsapp_dm_policy`
- `openclaw_whatsapp_allow_from`
- `openclaw_whatsapp_group_policy`

Set these secrets in `inventories/personal/group_vars/all/vault.yml`:

- `vault_openclaw_gateway_token`
- `vault_openclaw_zai_api_key` if you want GLM/Z.ai models

Bootstrap OpenAI Codex OAuth after the first successful deploy:

```bash
. ../.venv/bin/activate
kubectl -n openclaw exec -it deployment/openclaw -- sh -lc 'openclaw models auth login --provider openai-codex'
kubectl -n openclaw exec -it deployment/openclaw -- sh -lc 'openclaw models status && openclaw doctor'
```

The OpenClaw home directory lives on the PVC, so OAuth credentials survive pod
restarts and rollouts.

OpenClaw supports two origin TLS modes:

- `openclaw_tls_mode: letsencrypt` keeps the cert-manager DNS-01 flow through
  `openclaw_clusterissuer`
- `openclaw_tls_mode: cloudflare_origin_ca` loads a Cloudflare Origin CA
  certificate from local PEM files and stores it in the Kubernetes TLS secret

In `cloudflare_origin_ca` mode, browsers still see the Cloudflare edge
certificate. The Origin CA certificate secures only the Cloudflare to origin
hop, so direct browser access to the OpenClaw hostname without Cloudflare is
not a supported path.

If `vault_openclaw_zai_api_key` is present, the deployment also injects
`ZAI_API_KEY` into the gateway container. That enables GLM models through the
built-in `zai` provider.

WhatsApp support is optional. In this repo, the channel is only exposed when
both of these are true:

- `openclaw_whatsapp_enabled: true`
- `openclaw_web_enabled: true`

The rendered config seeds the minimal WhatsApp channel shape needed by
OpenClaw: `dmPolicy`, `allowFrom`, `groupPolicy`, and `accounts.<accountId>`.
Linked session data persists under
`~/.openclaw/credentials/whatsapp/<accountId>/`.

The deployment keeps `livenessProbe` on `/healthz` but uses `readinessProbe` on
`/`. In the current OpenClaw release, `/readyz` stays `503` until WhatsApp is
linked, which would otherwise block the public dashboard during first-time QR
pairing.

Because OpenClaw is behind Traefik in K3s, set
`openclaw_gateway_trusted_proxies` to the proxy IPs or CIDRs that front the
gateway. In a single-node K3s setup, trusting the pod CIDR such as
`10.42.0.0/16` restores local client detection for Control UI pairing.

Useful checks after deploy:

```bash
. ../.venv/bin/activate
kubectl -n openclaw get pvc,svc,ingress,secret openclaw-tls
kubectl -n openclaw rollout status deployment/openclaw
kubectl -n openclaw logs deployment/openclaw --tail=100
kubectl -n openclaw exec -it deployment/openclaw -- sh -lc 'openclaw channels status || true'
kubectl -n openclaw exec -it deployment/openclaw -- sh -lc 'openclaw channels login --channel whatsapp --account default'
kubectl -n openclaw get secret openclaw-secrets -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d && echo
```

----

## Cloudflare DNS-01

Cloudflare support is optional. If you do not use it, leave
`acme_dns_provider` as `none` and keep `validation_run_tls_smoke` disabled.

----

## Cloudflare Access for OpenClaw

Cloudflare Access lives in the Terraform workspace under
`../terraform/cloudflare-access/`. Use Terraform for:

- the OTP identity provider
- the self-hosted Access application
- the Access allow policy for the approved email address
- the proxied DNS record if you want Terraform to own that hostname
- the OpenClaw Origin CA certificate and local PEM files

Recommended rollout order:

1. apply the Terraform workspace
2. verify `https://openclaw.<domain>` shows the Cloudflare Access login page
3. set `cloudflare_access_enabled: true`
4. set `cloudflare_origin_lockdown_enabled: true`
5. rerun `playbooks/provision.yml`
6. rerun `playbooks/validate.yml`

When Access is enabled, the public hostname should redirect unauthenticated
requests to `*.cloudflareaccess.com`. OpenClaw still keeps its gateway token as
the second auth layer after Access login.

The origin lockdown applies to the whole VPS web ingress, not just OpenClaw.
Once enabled, direct origin-IP access to `80/tcp` and `443/tcp` should fail for
non-Cloudflare clients.

----

## Private admin access with Tailscale

Tailscale is optional, but it is the recommended way to remove public admin
ports from a single-user VPS. When enabled, the VPS joins your tailnet, the
admin kubeconfig points at the node's Tailscale address or MagicDNS hostname,
and firewalld stops exposing `22/tcp` and `6443/tcp` on the public interface.

Set these non-secret vars in `inventories/personal/group_vars/all/main.yml`:

- `tailscale_enabled`
- `tailscale_private_ssh_enabled`
- `tailscale_private_k3s_api_enabled`
- `tailscale_repo_url`
- `tailscale_hostname`
- `tailscale_accept_dns`
- `tailscale_ssh_enabled`
- `tailscale_tags`
- `tailscale_k3s_api_host`

Set this secret in `inventories/personal/group_vars/all/vault.yml`:

- `vault_tailscale_auth_key`

Recommended rollout order:

1. join your local Mac to the same tailnet first
2. create a reusable Tailscale auth key for the VPS
3. set `tailscale_enabled: true`
4. run `playbooks/provision.yml`
5. verify `ssh admin@<tailscale-ip>` and `kubectl` both work over Tailscale
6. set `tailscale_private_k3s_api_enabled: true`
7. rerun `playbooks/provision.yml`
8. rerun `playbooks/validate.yml`
9. only if you are comfortable removing the public SSH escape hatch, set `tailscale_private_ssh_enabled: true`
10. rerun `playbooks/provision.yml` and `playbooks/validate.yml`

If you prefer MagicDNS in the admin kubeconfig, set `tailscale_k3s_api_host`
explicitly. If you leave it empty, the kubeconfig will use the node's current
Tailscale IPv4 address instead.

For VPS hosts without a reliable console rescue path, keep `tailscale_private_ssh_enabled`
off at first and move only `6443/tcp` behind Tailscale. That leaves a narrow
public SSH break-glass path while `kubectl` is already private.

----

## SSH hardening

This repo keeps a hardened public SSH path for break-glass access unless you
explicitly move SSH behind Tailscale too. The default hardening model is:

- key-based login only
- root login disabled
- login limited to `ssh_allowed_users`
- lower auth and session thresholds than the stock distro defaults
- fail2ban watching the `sshd` journal and banning offenders through firewalld

Useful checks after changing SSH settings:

```bash
ssh admin@<public-ip> 'sudo sshd -T | egrep "^(permitrootlogin|passwordauthentication|authenticationmethods|allowusers|maxauthtries|maxsessions|maxstartups)"'
ssh admin@<public-ip> 'sudo fail2ban-client status sshd'
ssh admin@<tailscale-ip> 'hostname'
```
