# Synology Collection Refactor Plan
# Updated: 2026-03-31

---

## Architecture

```
Phase 1 (DSM HTTP API)           Phase 2 (SSH)
──────────────────────           ─────────────
interoperable.synology           interoperable.synology
.dsm_api role               →    .dsm_configuration role
(formerly synology_bootstrap)    (formerly synology_configuration)
```

---

## Completed

- ✅ `synology_bootstrap` role renamed → `dsm_api`
- ✅ All `synology_bootstrap_` var prefixes renamed → `synology_dsm_api_`
- ✅ FQCN updated: `interoperable.synology.dsm_api`
- ✅ Package install logic cleaned up (official packages only via HTTP API)
- ✅ `synology_bootstrap_package_list`: `[ContainerManager, Git, Virtualization]`
- ✅ Community packages moved to Phase 2 reference list only
- ✅ TASK A (original): `dsm_api` role covers SSH enable, package feeds, official packages, users, file services
- ✅ TASK B: `facts/device.yml` — clean `set_fact` dict, saves to local facts dir
- ✅ TASK C: `facts/packages.yml` — proper `stdout_lines` lists, `showall` gated behind `synology_refresh_packages`
- ✅ TASK D: `user_home_service.yml` — valid role task (no stray `hosts:` block), uses `synouser --create_homes`
- ✅ TASK E: `syno_community.yml` — no spksrc clone, `checkupdateall` gated behind `synology_refresh_packages`
- ✅ TASK F: `pip.yml` — uses `https://bootstrap.pypa.io/get-pip.py`, gated behind `synology_pip_upgrade`
- ✅ TASK G: `container_manager.yml` — hardware compat comment block, all tasks gated behind `synology_docker_enable`

---

## Remaining Work

### TASK H — Rename `synology_configuration` → `dsm_configuration`

Same pattern as the `dsm_api` rename. Touch:
- `roles/dsm_configuration/` → `roles/dsm_configuration/`
- All `synology_configuration` role references in plays, includes, README
- FQCN: `interoperable.synology.dsm_configuration`
- Inventory repo: `playbooks/synology_configure.yml` role reference
- Var prefix: `synology_dsm_configuration_` → `synology_dsm_configuration_` (if any)

---

### TASK I — Phase 2: Community package install via synopkg

Add to `dsm_configuration` role: install community packages (python314, byobu) over SSH.

**Why not HTTP API:** DSM API returns error 103 for all community/SynoCommunity packages.
`install_from_server` with community feeds is also blocked. Only path is local `.spk` install.

**Implementation:**
1. Download `.spk` from SynoCommunity to controller (using `get_url`)
2. Copy to NAS via `ansible.builtin.copy`
3. Install via `synopkg install <path>` with `become: true`
4. Verify with `synopkg list --name`
5. Clean up `.spk` from NAS

**New task file:** `roles/dsm_configuration/tasks/community_packages.yml`
**New defaults:**
```yaml
synology_dsm_community_packages:
  - name: python314
    spk_url: "https://packages.synocommunity.com/download/..."  # resolved at runtime
  - name: byobu
    spk_url: "https://packages.synocommunity.com/download/..."
synology_dsm_community_packages_tmp: /tmp/syno_spk
```

SynoCommunity SPK URL pattern:
`https://packages.synocommunity.com/?wd=<package>&arch=<arch>&build=<dsm_build>`

Arch and build are available from `synology_device_facts` (populated by `facts/device.yml`).

---

### TASK J — Timezone standardization

Both DS218+ (ds218p01, ds218p02) report timezone `Bogota` (GMT-5).
Verify if intentional or default-on-reset. If not, set via DSM API in `dsm_api` role:
`SYNO.Core.NTP` or `SYNO.Core.Regional` → set `time_zone` to `America/New_York`.

Add `synology_dsm_api_timezone` var (default: `""` = no change) and wire into `network.yml`.

---

## Execution Order

```
H (rename dsm_configuration) → I (community packages) → J (timezone)
```

Commit after each task.

---

## What This Does NOT Touch

- `cloudflare/`, `acme/`, `files.yml`, `git.yml`, `upptime.yml` — leave as-is
- All non-synology roles — untouched
