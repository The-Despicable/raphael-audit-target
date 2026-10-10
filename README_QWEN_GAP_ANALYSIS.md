# RAPHAEL G3 — Qwen Coder Web Gap Analysis (v7 Audit Snapshot)

This branch is an **immutable audit snapshot** published for source review by Qwen Coder Web.
It is **not** a code-review verdict, a gate acceptance, or a runtime authorization.

---

## Snapshot provenance

| Item | Value |
|---|---|
| Baseline commit | `fc3e2c132591eab7edaa12e97e13fe2d01619411` |
| Baseline tree | `e24d42bf7f7655293f3eb3a273c9ce4d94b1e061` |
| Snapshot branch | `audit/qwen-g3-v7-20261010` |
| v7 package path | `audit-snapshots/g3-remediation-v7-20261010/` |
| v7 manifest | `audit-snapshots/g3-remediation-v7-20261010/HANDOFF_MANIFEST_V7_20261010.md` |
| v7 manifest SHA-256 | `458ddc80d5e23c30c320ae21335b8b549bdc9d47ca192fd862f71e950cd19511` |
| v7 manifest verification | `sha256sum -c` → exit 0, 14 entries, 14 OK, 0 FAILED |

The repository source in this branch is the **frozen baseline tree**, so Qwen analyzes the actual
RAPHAEL code, not only the runner and the reports.

---

## What is in this snapshot

| Path | Contents |
|---|---|
| *(repository root)* | the RAPHAEL source tree at the baseline commit |
| `audit-snapshots/g3-remediation-v7-20261010/` | the complete verified v7 remediation package |
| `audit-snapshots/g3-remediation-v7-20261010/README_QWEN_GAP_ANALYSIS.md` | this file |

The v7 package contains:

- `g3-floor-run-v7-integrity.sh` — the hardened G3 test-floor runner (v7)
- `decisions/G3_OPERATOR_DECISIONS_V7.json` — machine-readable operator decisions
- `decisions/validate_decisions.py` — shared strict-JSON decision validator
- `decisions/ENUM_PROPOSAL_20261010.md` — **proposal only, NOT authorized**
- `REMEDIATION_HANDOFF_V7_20261010.md` — the v7 handoff and E-5…E-8 dispositions
- `HANDOFF_MANIFEST_V7_20261010.md` — integrity manifest (14 entries)
- `validation/` — validation evidence, isolated test output, manifest verification

---

## Scope of the requested analysis

Qwen Coder Web is asked to perform a **static gap analysis** of this snapshot. Recommended focus:

1. **Runner correctness (static review only).** Review
   `audit-snapshots/g3-remediation-v7-20261010/g3-floor-run-v7-integrity.sh` for defects in the
   fail-closed finalization (`finalize`), the stop-condition guards S1–S17, the S10 decision
   capture/ordering (E-1), the decision loading and path-containment logic (E-6), and the artifact
   integrity generation order (E-5/E-8). Identify any guard that could pass when it should stop.
2. **Decision validation.** Review `decisions/validate_decisions.py` for schema/type/consistency
   gaps — confirm it truly fails closed on missing, malformed, wrongly-typed and inconsistent
   input, and that it cannot be satisfied by a crafted artifact.
3. **Cross-consistency.** Check that the handoff, the enforcement matrix, the reconciliation file
   and the manifest agree, and that no claim overstates what was actually verified.
4. **Boundary and isolation logic.** Review `PROTECTED_LOCATIONS` and the normalized containment
   checks for bypasses (trailing slash, `..`, symlink or relative-path tricks).

---

## Explicit statements of fact

- **The v7 runner has NOT been executed.** It has only passed shell syntax validation
  (`bash -n`) and isolated unit tests. No floor run, benchmark, or application code was executed
  at any point in producing this snapshot. Static review and unit tests are **not** runtime proof.
- **G3 is NOT ACCEPTED.**
- **P4 and P10 are NOT AUTHORIZED.**
- **Runtime validation is NOT authorized.** Recording the approved 2,700-second ceiling does not
  authorize a run.

---

## Known outstanding blockers

| # | Blocker | State |
|---|---|---|
| 1 | **S5** — dependency-inventory expected digest not approved | Observed digest `a23b71564692d77f7b52d1525fbaed4f05ec654ab4b5510028b2bded14127be0` was retrieved and presented for approval; it is **unpinned** and unresolved. This blocks a compliant floor run. |
| 2 | **ENUM** — Git path-enumeration failure condition | **Proposed, NOT authorized.** The runner routes enumeration failure through the internal-error fail-closed path (`die_internal`, exit 3) and does not enforce any ENUM stop condition. |
| 3 | **C8** — independent review of the floor evidence | Unresolved. |
| 4 | **Roadmap §14.12 GLM adversarial review** | Outstanding. |

---

## Governance

This publication is for **source review only**. It does not constitute an audit, a gate
acceptance, or a runtime authorization. The required sequence remains:

**Implementation → evidence → independent audit → governance decision → separately authorized
runtime validation.**