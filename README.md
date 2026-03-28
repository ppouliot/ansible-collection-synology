# interoperable.synology

Ansible Collection for managing Synology NAS devices running DSM 7.x (with DSM 6.x backwards compatibility).

## Overview

This collection provides:

- **`interoperable.synology.synology_dsm_api_request`** — action plugin for making authenticated API calls to the Synology DSM API
- **`interoperable.synology.synology_dsm`** — role for configuring a Synology NAS (file services, terminal, users, packages)

## Requirements

- Ansible >= 2.12
- Python >= 3.6
- Synology DSM 6.x or 7.x

## Installation

```bash
ansible-galaxy collection install interoperable.synology
```

---

## `synology_dsm_api_request` Action Plugin

A low-level action plugin for making authenticated API requests to the Synology DSM API. Supports DSM 7.x SID-based authentication and DSM 6.x cookie-based authentication.

### Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `base_url` | no | `https://localhost:5001` | Base URL of the DSM (e.g. `http://nas.example.com:5000`) |
| `request_method` | no | `GET` | HTTP method: `GET` or `POST` |
| `login_sid` | no | — | **DSM 7.x** SID from login. Appended as `_sid` to GET query strings and POST bodies. |
| `login_cookie` | no | — | **DSM 6.x** legacy cookie string. Used only if `login_sid` is not set. |
| `validate_certs` | no | `True` | Set `false` to skip SSL cert validation (self-signed certs). |
| `cgi_path` | no | `/webapi/` | Path to the CGI directory. |
| `cgi_name` | no | `entry.cgi` | CGI script name. Use `auth.cgi` for authentication. |
| `api_name` | yes | — | Synology API name (e.g. `SYNO.API.Auth`, `SYNO.FileStation.List`) |
| `api_version` | no | `1` | API version number. |
| `api_method` | yes | — | API method (e.g. `login`, `logout`, `list`, `get`) |
| `api_params` | no | — | Additional parameters as a dict. URL-encoded for GET; merged into body for POST. |
| `request_json` | no | — | Raw JSON body for POST. Note: standard DSM endpoints require form-urlencoded; this parameter is for custom DSM packages that accept JSON. |

> **Note:** Real-world testing on a DS218 (DSM 7.x) confirmed that all standard DSM API endpoints require `application/x-www-form-urlencoded` request bodies. See [integration test results](roles/synology_dsm/tests/integration/TEST_RESULTS.md) for details.

### Examples

```yaml
# Login (DSM 7 SID-based)
- name: Login to DSM 7
  interoperable.synology.synology_dsm_api_request:
    base_url: "http://{{ synology_dsm_host }}:5000"
    cgi_name: auth.cgi
    api_name: SYNO.API.Auth
    api_version: "6"
    api_method: login
    request_method: POST
    validate_certs: false
    api_params:
      account: "{{ synology_dsm_username }}"
      passwd: "{{ synology_dsm_password }}"
      format: sid
  register: dsm_login
  no_log: true

- name: Store SID
  ansible.builtin.set_fact:
    dsm_sid: "{{ dsm_login.json.data.sid }}"

# Authenticated GET
- name: Get FileStation info
  interoperable.synology.synology_dsm_api_request:
    base_url: "http://{{ synology_dsm_host }}:5000"
    api_name: SYNO.FileStation.Info
    api_version: "2"
    api_method: get
    login_sid: "{{ dsm_sid }}"
    validate_certs: false

# Authenticated POST
- name: List shares
  interoperable.synology.synology_dsm_api_request:
    base_url: "http://{{ synology_dsm_host }}:5000"
    api_name: SYNO.FileStation.List
    api_version: "2"
    api_method: list_share
    request_method: POST
    login_sid: "{{ dsm_sid }}"
    validate_certs: false

# Logout
- name: Logout
  interoperable.synology.synology_dsm_api_request:
    base_url: "http://{{ synology_dsm_host }}:5000"
    cgi_name: auth.cgi
    api_name: SYNO.API.Auth
    api_version: "6"
    api_method: logout
    request_method: POST
    login_sid: "{{ dsm_sid }}"
    validate_certs: false
```

---

## `synology_dsm` Role

Configures a Synology NAS via the DSM API.

### Role Variables

| Variable | Default | Description |
|---|---|---|
| `synology_dsm_host` | `{{ inventory_hostname }}` | NAS hostname or IP |
| `synology_dsm_port` | `5000` | DSM HTTP port |
| `synology_dsm_base_url` | `http://{{ synology_dsm_host }}:{{ synology_dsm_port }}` | Full base URL |
| `synology_dsm_validate_certs` | `true` | Validate SSL certs |
| `synology_dsm_username` | `admin` | DSM username |
| `synology_dsm_password` | `changeme` | DSM password |
| `synology_dsm_auth_format` | `sid` | Auth format: `sid` (DSM 7) or `cookie` (DSM 6) |
| `synology_dsm_ssh_enable` | `true` | Enable SSH |
| `synology_dsm_ssh_port` | `22` | SSH port |
| `synology_dsm_telnet_enable` | `false` | Enable Telnet |
| `synology_dsm_nfs_enable` | `false` | Enable NFS |
| `synology_dsm_smb_enable` | `true` | Enable SMB |
| `synology_dsm_afp_enable` | `false` | Enable AFP (deprecated in DSM 7) |
| `synology_dsm_ftp_enable` | `false` | Enable FTP |
| `synology_dsm_rsync_enable` | `false` | Enable rsync |
| `synology_dsm_package_sources` | `[]` | List of `{name, feed}` package sources |

### Example Playbook

```yaml
- hosts: localhost
  collections:
    - interoperable.synology
  roles:
    - role: interoperable.synology.synology_dsm
      vars:
        synology_dsm_host: 192.168.1.100
        synology_dsm_port: 5000
        synology_dsm_validate_certs: false
        synology_dsm_username: admin
        synology_dsm_password: "{{ vault_synology_password }}"
        synology_dsm_ssh_enable: true
        synology_dsm_smb_enable: true
        synology_dsm_nfs_enable: true
```

---

## Integration Tests

All 8 integration tests pass against a real **Synology DS218 running DSM 7.x**, executed inside `ghcr.io/ansible/community-ansible-dev-tools:latest`.

| Test | Description | Result |
|---|---|---|
| T1 | Unauthenticated GET — API info endpoint | ✅ PASSED |
| T2 | DSM 7 SID login via POST (`auth.cgi`) | ✅ PASSED |
| T3 | Authenticated GET with `_sid` in query string | ✅ PASSED |
| T4 | Authenticated POST with `_sid` in form body | ✅ PASSED |
| T5 | `api_params` dict URL-encoding in GET | ✅ PASSED |
| T6 | Custom `cgi_path`/`cgi_name` URL construction | ✅ PASSED |
| T7 | Error propagation: `success: false` → `failed: true` | ✅ PASSED |
| T8 | Logout / SID invalidation | ✅ PASSED |

**Test artifacts:**
- Playbook: [`roles/synology_dsm/tests/integration/test_dsm7_plugin.yml`](roles/synology_dsm/tests/integration/test_dsm7_plugin.yml)
- Full results + run history: [`roles/synology_dsm/tests/integration/TEST_RESULTS.md`](roles/synology_dsm/tests/integration/TEST_RESULTS.md)
- Run logs: [`roles/synology_dsm/tests/integration/logs/`](roles/synology_dsm/tests/integration/logs/)
- Asciinema recording: [`assets/test-run.cast`](assets/test-run.cast)

Replay the test session:

```bash
asciinema play assets/test-run.cast
```

[![asciicast](assets/test-run.cast)](assets/test-run.cast)

---

## Licenses

- **Collection-level code:** [Apache-2.0](LICENSE)
- **`roles/synology_dsm`:** [MIT License](roles/synology_dsm/LICENSE) — originally authored by [Andrew Gaffney](https://github.com/agaffney/ansible-synology-dsm), modernized for DSM 7.x by [Interoperable Systems](https://interoperable.systems).

## Attribution

The `synology_dsm` role is derived from [agaffney/ansible-synology-dsm](https://github.com/agaffney/ansible-synology-dsm) and subsequently updated in [ppouliot/ansible-synology-dsm](https://github.com/ppouliot/ansible-synology-dsm) for DSM 7.x and Ansible 2.12+.

## Contributing

Please follow Ansible best practices, use FQCNs (`ansible.builtin.*`, `interoperable.synology.*`), and adhere to [Conventional Commits](https://www.conventionalcommits.org/).
