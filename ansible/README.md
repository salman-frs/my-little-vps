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
python -m pip install -r requirements.txt
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
git ls-files | xargs rg -n 'REPLACE_ME|CHANGE_ME' || true
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

- `cert_manager_enabled`: install cert-manager when `true`
- `acme_dns_provider`: set to `cloudflare` to enable Cloudflare-backed DNS-01 issuers
- `validation_run_tls_smoke`: issue a temporary ACME smoke certificate during validation when `true`
- `openclaw_enabled`: deploy OpenClaw into the cluster when `true`

The example inventory keeps DNS automation off by default. OpenClaw is enabled
in the example inventory, but its optional web and WhatsApp features remain off
until you turn them on explicitly.

----

## OpenClaw

When `openclaw_enabled: true`, the provision playbook applies a repo-managed
manifest bundle into the `openclaw` namespace. The deployment is exposed through
Traefik and can request a certificate from the configured ClusterIssuer.

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
kubectl -n openclaw get pvc,svc,ingress,certificate
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
