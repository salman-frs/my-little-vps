# my-little-vps

my-little-vps is an infrastructure repository for operating a personal
AlmaLinux 9 VPS with single-node K3s.

The repository uses Ansible to prepare the host, install K3s, and manage the
cluster services that run on top of it. The committed example inventory acts as
the reusable baseline for the project, while live host details and secrets stay
in a local personal inventory outside Git.

----

The repository covers the practical parts of running a small K3s server:
host provisioning, cluster installation, ingress through Traefik, optional
certificate management with cert-manager and Cloudflare DNS-01, and validation
playbooks for checking the resulting system.

Operational details live under [`ansible/`](./ansible/). The root README is the
front door for the repository; the operator guide contains the working
commands, inventory model, and service-specific notes.

----

## To start using my-little-vps

See the [Ansible operator guide].

To create a working local inventory from a fresh clone:

```bash
python3 -m venv .venv
. .venv/bin/activate
cd ansible
python -m pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
cp -R inventories/example inventories/personal
cp inventories/example/group_vars/all/vault.example.yml inventories/personal/group_vars/all/vault.yml
ansible-vault encrypt inventories/personal/group_vars/all/vault.yml
```

After that, edit the files in `inventories/personal/` for the target server and
run playbooks from the `ansible/` directory.

----

## To start operating my-little-vps

The [Ansible operator guide] contains the full operator workflow.

The repository is organized around three playbook flows:

- `playbooks/reset.yml` removes installed K3s state and related host artifacts
- `playbooks/provision.yml` prepares the host and applies the cluster stack
- `playbooks/validate.yml` checks host state, cluster health, and deployed services

Typical day-to-day operation looks like this:

```bash
cd ansible
. ../.venv/bin/activate
ansible-playbook -i inventories/personal/hosts.yml --ask-vault-pass playbooks/provision.yml
ansible-playbook -i inventories/personal/hosts.yml --ask-vault-pass playbooks/validate.yml
```

----

## Repository layout

- [`ansible/`](./ansible/) contains the automation workspace
- [`ansible/README.md`](./ansible/README.md) is the operator-facing guide
- `ansible/inventories/example/` is the committed baseline inventory
- `ansible/inventories/personal/` is the local working inventory for a real host

That split is central to the repository:

- reusable defaults and placeholders are committed
- live host metadata, domains, tokens, and vault data stay local

----

## Support

If you need support, start with the [Ansible operator guide] and run the
validation playbook before changing the server by hand.

If the issue is environment-specific, inspect `inventories/personal/` first.
If the issue is in shared automation, inspect the relevant playbook, role, or
template under [`ansible/`](./ansible/).

[Ansible operator guide]: ./ansible/README.md
