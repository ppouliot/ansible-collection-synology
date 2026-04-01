# interoperable.synology

Ansible Collection for managing Synology NAS devices running DSM 7.x.

## Requirements

- Ansible >= 2.12
- Synology DSM 7.x

## Bootstrap — Run Order

Provisioning requires **discrete runs** in order. Ansible loads `host_vars` at
startup — values written mid-run are not visible until the next invocation.

| Run | Tag | Interpreter | What happens |
|-----|-----|-------------|--------------|
| 1 | `dsm_api` | controller python | SSH enabled, SynoCommunity feed added, groups/feeds configured |
| 2 | `dsm_configuration` | `/bin/python3` (DSM built-in) | python314 installed, `host_vars` updated with python3.14 path |
| 3+ | `dsm_configuration` | `python3.14` (from host_vars) | Full Ansible capability — Docker, pip, containers |

```bash
# Run 1 — DSM API bootstrap
ansible-playbook -i inventory/ site.yml --tags dsm_api

# Run 2 — SSH bootstrap, installs python314, writes host_vars
ansible-playbook -i inventory/ site.yml --tags dsm_configuration

# Run 3+ — Full configuration with python3.14
ansible-playbook -i inventory/ site.yml --tags dsm_configuration
```

## Installation

```bash
ansible-galaxy collection install interoperable.synology
```

## Roles

| Role | Description |
|------|-------------|
| `synology_dsm` | Configure a Synology NAS running DSM 7.x (users, file services, packages, terminal) |

## Usage

```yaml
- hosts: localhost
  roles:
    - role: interoperable.synology.synology_dsm
      vars:
        synology_dsm_host: 192.168.1.100
        synology_dsm_username: admin
        synology_dsm_password: "{{ vault_synology_password }}"
```

## Licenses

This collection contains code under multiple licenses:

- **Collection-level code:** [Apache-2.0](LICENSE)
- **`roles/synology_dsm`:** [MIT License](LICENSES/MIT.txt) — originally authored by
  [Andrew Gaffney](https://github.com/agaffney/ansible-synology-dsm).
  The MIT license is retained verbatim in `roles/synology_dsm/LICENSE` and `LICENSES/MIT.txt`.

## Attribution

The `synology_dsm` role is derived from [agaffney/ansible-synology-dsm](https://github.com/agaffney/ansible-synology-dsm),
modernized for DSM 7.x and Ansible 2.12+ by [Interoperable Systems](https://interoperable.systems).

## Contributing

Please follow Ansible best practices, use FQCNs (`ansible.builtin.*`), and adhere to
[Conventional Commits](https://www.conventionalcommits.org/). All PRs are linted via GitHub Actions.
