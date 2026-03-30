# Merge Plan: DSM 7 Action Plugin into interoperable/ansible-collection-synology

**Branch:** feat/dsm7-action-plugin → interoperable/main  
**PR:** https://github.com/interoperable/ansible-collection-synology/pull/1  
**Constraint:** Do NOT touch any existing roles or files. This is purely additive.  
**Verification target:** http://172.19.0.43:5000 (DS218, DSM 7.x)

---

## Task 1 — Verify existing collection is untouched

```bash
cd /Users/peter/.openclaw/workspace/ansible-collection-synology
git diff interoperable/main -- roles/synology_configuration/
git diff interoperable/main -- roles/synology_monitoring/
```

Expected: zero diff. If any existing role file shows a diff, STOP and report it.

---

## Task 2 — Verify the action plugin loads correctly

```bash
cd /Users/peter/.openclaw/workspace/ansible-collection-synology
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  -e ANSIBLE_ACTION_PLUGINS=/workspace/plugins/action \
  ghcr.io/ansible/community-ansible-dev-tools:latest \
  python3 -c "import importlib.util, sys; spec = importlib.util.spec_from_file_location('synology_dsm_api_request', '/workspace/plugins/action/synology_dsm_api_request.py'); mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); print('PLUGIN LOADED OK:', mod.ActionModule)"
```

Expected: `PLUGIN LOADED OK: <class '...ActionModule'>` with no errors.  
If it fails: report the exact error message.

---

## Task 3 — Run the integration test suite against the live DSM

```bash
cd /Users/peter/.openclaw/workspace/ansible-collection-synology
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG="roles/synology_dsm/tests/integration/logs/merge-verify-${TIMESTAMP}.log"
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  -e ANSIBLE_FORCE_COLOR=0 \
  -e ANSIBLE_ACTION_PLUGINS=/workspace/plugins/action \
  ghcr.io/ansible/community-ansible-dev-tools:latest \
  ansible-playbook \
    -i roles/synology_dsm/tests/integration/inventory.ini \
    roles/synology_dsm/tests/integration/test_dsm7_plugin.yml -v \
  2>&1 | tee "$LOG"
```

Expected: `ok=18  failed=0  ignored=1` (T7 is intentionally ignored).  
If any unexpected test fails: report the task name, DSM error code, and full JSON response. Do NOT proceed to Task 4.

---

## Task 4 — Commit the verification log and push

```bash
cd /Users/peter/.openclaw/workspace/ansible-collection-synology
git add roles/synology_dsm/tests/integration/logs/
git commit -m "test: merge verification run — all 8 integration tests passing"
git push interoperable feat/dsm7-action-plugin
```

---

## Task 5 — Report

Reply with:
- Task 1 result: CLEAN or list of unexpected diffs
- Task 2 result: DOCS OK or error
- Task 3 result: test summary table (T1–T8 PASSED/FAILED)
- Task 4 result: commit hash and push status
- Final verdict: READY TO MERGE or BLOCKED (with reason)

Do nothing else. Do not merge. Peter will merge after reviewing the report.
