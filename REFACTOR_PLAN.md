# Synology Collection Refactor Plan
# Goal: DSM API bootstrap → SSH handoff → full automation
# Status: PLANNING (do not execute yet)

---

## Architecture

```
Phase 1 (DSM API)          Phase 2 (SSH)
─────────────────          ─────────────
ppouliot.synology          ppouliot.synology
.synology_dsm role    →    .synology_configuration role
                           (refactored)
```

Phase 1 uses the new `synology_dsm_api_request` plugin to:
- Enable SSH via the DSM API (no prior SSH needed)
- Inject the operator's public key
- Return a ready-to-use SSH connection

Phase 2 takes over via SSH to do everything that requires shell access.

---

## Task Breakdown for Cornholio

Each task is sized to fit in a 32k context window.
Do NOT start a task until the previous one is committed and pushed.
Branch: `feat/dsm7-action-plugin` (already open, builds on existing PR #1)

---

### TASK A — New role: `synology_bootstrap` (DSM API → SSH enablement)

**Files to create:**
```
roles/synology_bootstrap/
  tasks/
    main.yml
    enable_ssh.yml
    inject_ssh_key.yml
    verify_ssh.yml
  defaults/main.yml
  meta/main.yml
  README.md
```

**What it does (in order):**
1. `enable_ssh.yml` — use `ppouliot.synology.synology_dsm_api_request` to:
   - Login → get SID
   - POST to `SYNO.Core.Terminal` to enable SSH on `synology_bootstrap_ssh_port`
   - Logout
2. `inject_ssh_key.yml` — use `ppouliot.synology.synology_dsm_api_request` to:
   - Login → get SID
   - POST to `SYNO.Core.User.PasswordConfirm` or use the existing `ssh_keys.yml` approach
     (NOTE: key injection requires SSH already up — inject via DSM file write if API supports it,
     otherwise document that `sshkey_url` must be set and injected on first SSH connect)
   - Logout
3. `verify_ssh.yml` — `ansible.builtin.wait_for` on port `synology_bootstrap_ssh_port`
   to confirm SSH is accepting connections before handing off

**Defaults:**
```yaml
synology_bootstrap_ssh_port: 22
synology_bootstrap_ssh_enable: true
synology_bootstrap_validate_certs: true
synology_bootstrap_sshkey_url: ""   # e.g. https://github.com/ppouliot.keys
```

**Pass criteria:** `wait_for` returns within timeout, port is open.

---

### TASK B — Refactor `facts/device.yml` → `synology_facts` module

**Problem:** Current `device.yml` is a wall of 40+ `debug` tasks that just print facts.
It doesn't save anything, doesn't set any custom vars, and spams the play output.

**Fix:** Rewrite as a single structured `set_fact` that captures only the useful Synology-specific
fields into a `synology_device` dict. Keep SSH-based `ansible.builtin.setup` call.

**File:** `roles/synology_configuration/tasks/facts/device.yml`

Replace the entire file with:
```yaml
---
- name: Gather Ansible facts
  ansible.builtin.setup:
  when: not ansible_facts.keys() | list | length

- name: Set synology_device facts
  ansible.builtin.set_fact:
    synology_device:
      model: "{{ ansible_facts.proc_cmdline.syno_hw_version | default('unknown') }}"
      serial: "{{ ansible_facts.proc_cmdline.sn | default('unknown') }}"
      firmware: "{{ ansible_facts.proc_cmdline.syno_fw_version | default('unknown') }}"
      arch: "{{ ansible_facts.architecture | default('unknown') }}"
      mac_addresses: "{{ ansible_facts.proc_cmdline.macs | default('') }}"
      hostname: "{{ ansible_facts.hostname | default(inventory_hostname) }}"
      interfaces: "{{ ansible_facts.proc_cmdline.netif_num | default('unknown') }}"
      distribution: "{{ ansible_facts.distribution | default('unknown') }}"
      distribution_version: "{{ ansible_facts.distribution_version | default('unknown') }}"

- name: Display synology_device facts
  ansible.builtin.debug:
    var: synology_device
```

**Pass criteria:** `synology_device` fact is set and `synology_device.model` is not 'unknown'.

---

### TASK C — Refactor `facts/packages.yml`

**Problem:** Uses raw `stdout` strings, not lists. `synology_all_packages` fact clobbers the
registered var of the same name. Debug dumps entire package list to output.

**Fix:**
```yaml
---
- name: Get installed Synology packages
  ansible.builtin.command: /usr/syno/bin/synopkg list --name
  changed_when: false
  register: _synopkg_installed

- name: Set synology_installed_packages fact (list)
  ansible.builtin.set_fact:
    synology_installed_packages: "{{ _synopkg_installed.stdout_lines }}"

- name: Show installed package count
  ansible.builtin.debug:
    msg: "{{ synology_installed_packages | length }} packages installed"
```

Drop the `showall` call — it's slow and the output is rarely useful in automation.

**Pass criteria:** `synology_installed_packages` is a list, not a string.

---

### TASK D — Fix `user_home_service.yml`

**Problem:** File is completely broken — it has `hosts:` and `tasks:` blocks inside a role task
file (it's a full playbook accidentally pasted into a task file). It will fail with a parse error.

**Fix:** Rewrite as a proper role task using `ansible.builtin.lineinfile` and
`ansible.builtin.command` to restart the service. No `hosts:` block.

```yaml
---
- name: Enable user home service
  become: true
  block:
    - name: Enable user home in synoinfo.conf
      ansible.builtin.lineinfile:
        path: /etc/synoinfo.conf
        regexp: '^support_user_home='
        line: 'support_user_home="yes"'
        state: present
      register: _user_home_changed

    - name: Restart user home service
      ansible.builtin.command: synoservicectl --restart SYNO.Core.UserHome
      when: _user_home_changed.changed
      changed_when: true
```

**Pass criteria:** File is syntactically valid (`ansible-playbook --syntax-check`).

---

### TASK E — Fix `syno_community.yml`

**Problem:**
- The git clone of `spksrc` (2GB repo) has nothing to do with adding a package source — wrong task, wrong repo.
- `checkupdateall` runs unconditionally every play.

**Fix:**
- Remove the `ansible.builtin.git` spksrc clone entirely.
- Gate `checkupdateall` behind a `when: synology_refresh_packages | default(false)` var.
- Keep the feeds template task.

---

### TASK F — Fix `pip.yml`

**Problem:** Hardcoded to Python 3.8 pip bootstrap URL. DSM 7 ships Python 3.x by default.

**Fix:** Update URL to current `https://bootstrap.pypa.io/get-pip.py` and add a `when:` guard
so pip install only runs if `synology_pip_upgrade: true`.

---

### TASK G — Annotate `container_manager.yml` and `docker` templates as DSM-version-gated

**Problem:** Container Manager vs legacy Docker package name differs by DSM version.
Some tasks will silently fail on models without virtualization support.

**Fix (minimal, no breakage):**
- Add `when: synology_docker_enable | default(false)` guards throughout (most are missing).
- Add a comment block at the top of `container_manager.yml` noting which DSM versions and
  hardware models support Container Manager vs Docker.
- Do NOT refactor logic yet — leave for the next phase when test hardware is available.

---

## What This Does NOT Touch (yet)

- `cloudflare/ddns.yml` — functional, leave as-is
- `acme/` — functional, leave as-is
- `files.yml`, `git.yml`, `upptime.yml` — leave as-is
- `handlers/main.yml` — leave as-is
- All other roles in the collection — untouched

---

## Execution Order

```
A → B → C → D → E → F → G
```

Commit after each task. Each task is independent — a failure in one does not block others
except Task A (bootstrap) which must pass before any SSH-dependent work.

---

## Token Budget Note

Each task fits in a single Cornholio run (32k context).
Do not combine tasks. Do not read files that aren't needed for the current task.
