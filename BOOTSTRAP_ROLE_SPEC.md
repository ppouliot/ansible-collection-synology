# synology_bootstrap Role Specification
# Target: DSM 7.x API-only (no SSH required)
# Branch: feat/dsm7-action-plugin

---

## Purpose

Bootstrap a Synology NAS from zero using only the DSM HTTP API.
No SSH required at start. SSH is enabled and configured as part of this role.
Hands off to `synology_configuration` (SSH-based) when complete.

---

## Architecture

Single role, task files per concern. All tasks use `ppouliot.synology.synology_dsm_api_request`.
Login/logout handled once in `main.yml` — SID passed to all subtasks via `synology_bootstrap_sid`.

---

## Task Files

### `tasks/main.yml`
Orchestrator. Login → run all subtasks in order → logout.

### `tasks/login.yml`
- `SYNO.API.Auth` login → register `synology_bootstrap_sid`

### `tasks/system_info.yml`
- `SYNO.Core.System` get → set `synology_system_info` fact (firmware version, model, serial)
- `SYNO.DSM.Info` get → set `synology_dsm_info` fact

### `tasks/users.yml`
- `SYNO.Core.User` list → register current users
- `SYNO.Core.User` create → loop over `synology_bootstrap_users`
- `SYNO.Core.User` set password, description, email
- `SYNO.Core.User.Home` set → enable user home service (always runs first)

### `tasks/groups.yml`
- `SYNO.Core.Group` list → register current groups
- `SYNO.Core.Group.Member` add → loop over `synology_bootstrap_group_members`
  (e.g. add user to administrators group)

### `tasks/user_home.yml`
- `SYNO.Core.User.Home` set → enable=true, location, recycle_bin
- Must run BEFORE users.yml so homes are created on user add

### `tasks/package_feeds.yml`
- `SYNO.Core.Package.Feed` list → get current feeds
- `SYNO.Core.Package.Feed` add → loop over `synology_bootstrap_package_feeds`
  (idempotent: skip if feed name already present)

### `tasks/packages.yml`
- `SYNO.Core.Package.Server` list → discover available packages
- `SYNO.Core.Package` list → get installed packages
- `SYNO.Core.Package.Installation` install_from_server → loop over `synology_bootstrap_packages`
  (idempotent: skip if already installed)
- `SYNO.Core.Package.Progress` poll → wait for install to complete

### `tasks/ssh.yml`
- `SYNO.Core.Terminal` set → enable SSH, set port
- `ansible.builtin.wait_for` → verify SSH port is open before continuing

### `tasks/file_services.yml`
- `SYNO.Core.FileServ.SMB` set → enable/disable SMB, workgroup, settings
- `SYNO.Core.FileServ.NFS` set → enable/disable NFS, v4, v4.1
- `SYNO.Core.FileServ.AFP` set → enable/disable AFP
- `SYNO.Core.FileServ.FTP` set → enable/disable FTP
- `SYNO.Core.FileServ.FTP.SFTP` set → enable/disable SFTP
- `SYNO.Core.FileServ.Rsync` → enable/disable rsync

### `tasks/shares.yml`
- `SYNO.Core.Share` list → get current shares
- `SYNO.Core.Share` create → loop over `synology_bootstrap_shares`
- `SYNO.Core.Share.Permission` set → loop over share permissions

### `tasks/network.yml`
- `SYNO.Core.Network` get → register current network config
- `SYNO.Core.DDNS.Record` list/create → if `synology_bootstrap_ddns` defined
- `SYNO.Core.Region.NTP` set → configure NTP servers

### `tasks/security.yml`
- `SYNO.Core.Security.AutoBlock` set → configure auto-block
- `SYNO.Core.Security.Firewall` → enable/configure firewall rules
- `SYNO.Core.Security.DSM` set → HTTPS redirect, TLS settings
- `SYNO.Core.Certificate` → manage certs if `synology_bootstrap_cert` defined

### `tasks/notifications.yml`
- `SYNO.Core.Notification.Mail` → configure email notifications
- `SYNO.Core.Notification.Push` → configure push notifications

### `tasks/logout.yml`
- `SYNO.API.Auth` logout

---

## Action Plugin Extensions Needed

The current `synology_dsm_api_request` plugin needs:

1. **`task_vars` SID injection** — auto-inject `synology_bootstrap_sid` from task vars
   so subtasks don't need to manually pass `login_cookie` every time.

2. **`ignore_errors` on 103** — option to treat error code 103 (access denied) as a warning
   rather than a fatal failure, for graceful degradation.

3. **`poll_until_done`** — new option to poll `SYNO.Core.Package.Progress` until
   `finished=true` for async installs.

---

## Default Variables (`defaults/main.yml`)

```yaml
# Auth
synology_bootstrap_dsm_url: "http://{{ inventory_hostname }}:5000"
synology_bootstrap_username: admin
synology_bootstrap_password: ""
synology_bootstrap_validate_certs: false

# Features to enable (all default false — opt-in)
synology_bootstrap_enable_user_home: true
synology_bootstrap_user_home_location: "/volume1"
synology_bootstrap_enable_ssh: true
synology_bootstrap_ssh_port: 22
synology_bootstrap_enable_smb: true
synology_bootstrap_enable_nfs: false
synology_bootstrap_enable_afp: false
synology_bootstrap_enable_ftp: false

# Users to create (list of dicts)
synology_bootstrap_users: []
# - name: beavis
#   password: "changeme"
#   groups: [administrators, users]
#   email: ""
#   description: ""

# Group membership (list of dicts)
synology_bootstrap_group_members: []
# - group: administrators
#   members: [beavis, peter]

# Package feeds (list of dicts)
synology_bootstrap_package_feeds:
  - name: SynoCommunity
    feed: https://packages.synocommunity.com

# Packages to install (list of package IDs)
synology_bootstrap_packages: []
# - Git
# - Python3

# Shares (list of dicts)
synology_bootstrap_shares: []

# NTP
synology_bootstrap_ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
```

---

## Test Playbook (`test_bootstrap_ds218.yml`)

Validates against 172.19.0.43 (DS218):
1. Run `synology_bootstrap` role (API phase)
2. Assert: SSH up, user homes enabled, SynoCommunity feed present, Git installed
3. Run `synology_configuration` role (SSH phase, docker disabled)
4. Assert: facts gathered, pip installed, ssh keys injected

---

## Execution Order (Cornholio Tasks)

```
Task 1: Action plugin extensions (poll_until_done, SID injection)
Task 2: defaults/main.yml + tasks/main.yml scaffold
Task 3: tasks/login.yml + tasks/system_info.yml + tasks/logout.yml
Task 4: tasks/user_home.yml + tasks/users.yml + tasks/groups.yml
Task 5: tasks/package_feeds.yml + tasks/packages.yml
Task 6: tasks/ssh.yml
Task 7: tasks/file_services.yml + tasks/shares.yml
Task 8: tasks/network.yml + tasks/security.yml + tasks/notifications.yml
Task 9: test_bootstrap_ds218.yml + integration test against 172.19.0.43
```

Each task: commit before moving to next.
