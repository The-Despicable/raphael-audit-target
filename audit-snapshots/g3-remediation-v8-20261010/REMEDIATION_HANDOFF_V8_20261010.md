# RAPHAEL G3 — v8 Remediation Handoff (QW-01 … QW-06)

**Prepared:** 2026-10-10
**Implementation agent:** RAPHAEL — Space Bunny
**Independent reviewer:** RAPHAEL-Auditor / Qwen Coder Web (**review NOT performed**)
**Baseline (immutable):** `7851bf151a7fa4b05cad618509697e84ff5b05da` on `audit/qwen-g3-v7-20261010`
**Candidate branch:** `remediation/g3-v8-qw01-qw02-qw04-20261010`
**Package:** `audit-snapshots/g3-remediation-v8-20261010/`

> **The v8 runner has NEVER been executed.** `bash -n` and isolated unit tests are **not** runtime
> validation. This candidate is an implementation artifact for independent review, not an accepted
> remediation and not gate acceptance.

---

## 1. Candidate identity

| Item | Value |
|---|---|
| Baseline commit | `7851bf151a7fa4b05cad618509697e84ff5b05da` |
| Baseline tree | `e7a5f351a42c742cf4a14309e7c401be74f4a1fb` |
| New branch | `remediation/g3-v8-qw01-qw02-qw04-20261010` |
| New package | `audit-snapshots/g3-remediation-v8-20261010/` |
| Changed files | `g3-floor-run-v8-integrity.sh` (from v7), `g3_v8_lib.sh` (**new**), `decisions/G3_OPERATOR_DECISIONS_V8.json` (renamed, values unchanged), `validation/test_v8_regressions.sh` (**new**), `validation/test_v8_decisions.sh` (rewritten relocatable), `FINDINGS_DISPOSITION_MATRIX_V8.md` (**new**), `REMEDIATION_HANDOFF_V8_20261010.md` (this file), manifest + validation outputs |

## 2. Changes made

| File | Purpose |
|---|---|
| `g3_v8_lib.sh` | **New shared production library.** `g3_realpath_m`, `g3_contains`, `g3_norm_path`, `g3_s14_boundary_violation` (QW-01); `g3_hash_account`, `g3_s7_set_equal`, `g3_s7_descriptive_digest` (QW-02/QW-03); `g3_norm_bool` (QW-04). Sourced by both runner and tests. |
| `g3-floor-run-v8-integrity.sh` | Sources the library; S14 boundary now delegates to `g3_s14_boundary_violation`; S16 boolean normalized once at the loader; S7 before/after accounting rewritten to the complete unhashed set; v8 runtime paths and version stamp. |
| `decisions/G3_OPERATOR_DECISIONS_V8.json` | Renamed copy of the v7 decision artifact. **Values unchanged** (2700 s ceiling, 1200 s minimum, INCLUDE_VENV, S17 retained, S5 null, ENUM unauthorized, `runtime_validation_authorized:false`). |
| `decisions/validate_decisions.py` | Unchanged from v7 — strict JSON validation preserved; the v8 runner normalizes its *output* rather than weakening validation. |
| `decisions/ENUM_PROPOSAL_20261010.md` | Unchanged; still `PROPOSED_NOT_AUTHORIZED`. |
| `validation/test_v8_regressions.sh` | **New** — QW-01/02/03/04 regression tests against the real library. |
| `validation/test_v8_decisions.sh` | Rewritten — relocatable, keeps S5/S10/S16/S17/ENUM and E-1 ordering coverage. |

## 3. Finding dispositions

See `FINDINGS_DISPOSITION_MATRIX_V8.md`. Summary: **QW-01 FIXED · QW-02 FIXED · QW-04 FIXED ·
QW-06 FIXED · QW-03 PARTIALLY FIXED (contract aligned, operator decision requested) · QW-08 deferred
· QW-09 not confirmed.**

## 4. Validation performed (none is runtime)

| Check | Command | Result | Exit |
|---|---|---|---|
| Runner syntax | `bash -n g3-floor-run-v8-integrity.sh` | parse OK | **0** |
| Library syntax | `bash -n g3_v8_lib.sh` | parse OK | **0** |
| QW-01/02/03/04 regressions | `bash validation/test_v8_regressions.sh` | **30 PASS / 0 FAIL** | **0** |
| Decision regression | `bash validation/test_v8_decisions.sh` | **17 PASS / 0 FAIL** | **0** |
| v7 bypass reproduction (pre-fix) | demo against the published v7 `norm_path` | bypass reproduced (`..` traversal **not** stopped) | — |
| QW-04 before/after comparison | demo of v7 vs v8 decision-consumption | v7 aborts; v8 selects INCLUDE_VENV | — |
| Hard-coded path audit | `grep '/home/yaser' validation/test_v8_*.sh` | none in v8 tests | — |

**Not performed (prohibited):** executing `g3-floor-run-v8-integrity.sh`, the G3 floor suite,
Raphael application code, benchmarks, or any live runtime validation. Failure paths were exercised
only through isolated fixture tests against library functions, never through the runner.

## 5. Manifest

The package manifest `HANDOFF_MANIFEST_V8_20261010.md` is generated **last**, after all package
content is final, and is then verified with a real `sha256sum -c`. The verification record is in
`validation/manifest_verify_summary.txt` with actual matched/mismatched counts. The manifest excludes
itself (self-reference) and the reason is documented in `validation/manifest_inventory_check.txt`.

## 6. Preservation

- The immutable v7 package and the v7 publication branch are **unchanged**.
- v1–v6 evidence packages are **unchanged**.
- The local source repository (`/home/yaser/external-audits/raphael-2`) is **unchanged** — this work
  occurred only inside the isolated publication workspace at `/home/yaser/audit-rsi1/_qwen_publish_ws`.

## 7. Outstanding issues

1. **QW-03 governing interpretation** — whether S7 authorization is digest-based, set-based, or
   diff-based is not unambiguously fixed by the packet. Operator decision requested; v8 implements
   set equality + raw diff and labels the digest descriptive.
2. **QW-08** — unchecked ledger writes deferred; no false-success path demonstrated.
3. **QW-09** — timeout classification untouched pending concrete evidence.
4. **No runtime validation** — the three fixes are code- and fixture-verified only.

## 8. Governance

Unchanged and explicitly confirmed:

- **G3: NOT ACCEPTED**
- **P4/P10: NOT AUTHORIZED**
- **S5: UNPINNED / PENDING OPERATOR APPROVAL** (observed `a23b7156…` not pinned)
- **ENUM: PROPOSED_NOT_AUTHORIZED** (not enforced)
- **C8: UNRESOLVED**
- **§14.12 GLM adversarial review: OUTSTANDING**
- **Runtime validation: NOT AUTHORIZED**

S10 ceiling **2,700 s**; E-2 minimum **1,200 s** — both unchanged. Recording the ceiling does not
authorize execution. No decision was changed to make a test pass.

**This candidate does not self-accept G3 and does not claim independent review is complete.**
Required sequence: Implementation → evidence → independent audit → governance decision → separately
authorized runtime validation.