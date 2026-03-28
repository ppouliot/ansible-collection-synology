# interoperable.synology

Ansible Collection for managing Synology NAS devices running DSM 7.x.

## Requirements

- Ansible >= 2.12
- Synology DSM 7.x

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

- **Collection-level code:** [GPL-2.0-or-later](LICENSE)
- **`roles/synology_dsm`:** [MIT License](LICENSES/MIT.txt) — originally authored by
  [Andrew Gaffney](https://github.com/agaffney/ansible-synology-dsm).
  The MIT license is retained verbatim in `roles/synology_dsm/LICENSE` and `LICENSES/MIT.txt`.

## Attribution

The `synology_dsm` role is derived from [agaffney/ansible-synology-dsm](https://github.com/agaffney/ansible-synology-dsm),
modernized for DSM 7.x and Ansible 2.12+ by [Interoperable Systems](https://interoperable.systems).

## Contributing

Please follow Ansible best practices, use FQCNs (`ansible.builtin.*`), and adhere to
[Conventional Commits](https://www.conventionalcommits.org/). All PRs are linted via GitHub Actions.
