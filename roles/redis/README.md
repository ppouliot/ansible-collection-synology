# interoperable.synology.redis

Installs and manages Redis from [SynoCommunity](https://synocommunity.com/) on Synology NAS running DSM 7.x.

Redis is installed via `synopkg` using a NAS-side SPK download — the NAS fetches the SynoCommunity catalog and downloads the package directly, avoiding controller-to-NAS binary transfers.

## Requirements

- Synology DSM 7.x
- SynoCommunity package feed already added (use the `dsm_api` role)
- `become: true` capable SSH user on the NAS

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `redis_package_name` | `redis` | SynoCommunity package name |
| `redis_port` | `6379` | Redis listening port |
| `redis_bind` | `0.0.0.0` | Redis bind address |
| `redis_password` | `""` | Redis auth password (empty = no auth) |
| `redis_maxmemory` | `256mb` | Max memory limit |
| `redis_maxmemory_policy` | `allkeys-lru` | Eviction policy |
| `synology_dsm_arch` | `apollolake` | NAS CPU architecture for SPK selection |
| `synology_dsm_build` | `86009` | DSM build number for SPK compatibility |
| `synology_dsm_spk_tmp` | `/tmp/syno_spk` | Temp directory for SPK download on NAS |

## Example Playbook

```yaml
- name: Install Redis on Synology NAS
  hosts: synology
  gather_facts: true
  roles:
    - role: interoperable.synology.redis
      vars:
        synology_dsm_arch: apollolake
        synology_dsm_build: "86009"
```

Or use the dedicated bootstrap playbook which also ensures the SynoCommunity feed is present:

```bash
# Step 1: add SynoCommunity feed
ansible-playbook playbooks/redis_bootstrap.yml --tags dsm_api

# Step 2: install Redis
ansible-playbook playbooks/redis_bootstrap.yml --tags redis
```

## Handlers

| Handler | Trigger |
|---|---|
| `Restart redis` | Notified by tasks that modify Redis config |

## Notes

- Idempotent: skips download/install if Redis is already installed
- SPK is cleaned up from `/tmp/syno_spk/` after install
- Designed as a prerequisite for switching Ansible `fact_caching` from `jsonfile` to `redis`
