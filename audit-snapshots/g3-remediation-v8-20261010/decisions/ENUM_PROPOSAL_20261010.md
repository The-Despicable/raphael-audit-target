# ENUM — Git Path-Enumeration Failure Condition: PROPOSAL

**Status:** `PROPOSED_NOT_AUTHORIZED`
**Date:** 2026-10-10
**This proposal does not modify the canonical authorization packet and does not activate any identifier.**

---

## v7 package note (documentation-only, added 2026-10-10)

This is an **unmodified copy** of the ENUM proposal, carried into the v7 package so the v7
runner's reference resolves. It originated in the v5 package
(`g3-remediation-decisions-20261010/decisions/ENUM_PROPOSAL_20261010.md`).

**Its status is unchanged: `PROPOSED_NOT_AUTHORIZED`.** Copying it here does **not** activate
ENUM, does **not** grant it an authorized status, and does **not** modify the canonical
authorization packet. The v7 runner still does **not** enforce ENUM; Git path-enumeration failure
is routed through the internal-error fail-closed path (`die_internal`, exit 3), which records
INTERNAL rather than claiming an authorized S-condition was violated.

*(E-7 correction: the v6 runner referenced `decisions/ENUM_PROPOSAL_20261010.md`, which was absent
from the v6 package — a dangling reference. The proposal is now co-located with the v7 runner that
cites it.)*

---

---

## 1. Problem

The authorized stop-condition matrix (packet §8, lines 570–596) defines S1–S17. **None of them
covers a failure to enumerate tracked paths.**

A run reaches this state when `git ls-files -z` fails — for example a corrupt or unreadable index,
an invalid repository, or an I/O error. At that moment:

- `FP_tracked.z` is empty or truncated;
- `FP_BEFORE.sha256` cannot be built from a complete file set;
- **no manifest exists**, so S6 (count mismatch between two built manifests) and S17 (the summary
  reporting `SCOPE_MISMATCH`) have nothing to compare.

v2 mislabelled this as S17; v3 continued to call it S17; **v4 corrected the mislabelling** by
introducing `ENUM` as its own condition. **That correction is a code-level remedy for an
authorization gap — the gap itself is still open.**

## 2. Proposed condition

| Field | Value |
|---|---|
| **Proposed ID** | `ENUM` |
| **Proposed condition** | Git path enumeration (`git ls-files`) fails, or yields an empty file list, so the tracked-file inventory cannot be established |
| **Classification** | environment / precondition — *proposed*, not authorized |
| **Failure semantics** | hard stop; the run cannot produce a meaningful manifest |
| **Proposed exit** | fail-closed (a violated stop condition, not a blocked authorization) |

## 3. Why enumeration failure is distinct from S6 and S17

| | Condition | Precondition state | Comparison available? |
|---|---|---|---|
| **S6** | `FP_BEFORE` line count ≠ `FP_AFTER` line count | **both manifests built** | yes — counts compared |
| **S17** | `FP_diff_summary.txt` reports `SCOPE_MISMATCH` | manifests built; summary emitted | yes — summary inspected |
| **`ENUM`** | enumeration failed / returned empty | **no manifest exists** | **no — nothing to compare** |

Folding enumeration failure into S6 or S17 would assert a comparison that never happened. That is
precisely the mislabelling v4 withdrew.

## 4. Proposed trigger and evidence

**Trigger (all proposed, none active):**

```
git -C "$WT" ls-files -z > "$ART/FP_tracked.z"
rc=$?
[ "$rc" -ne 0 ] and stop ENUM "git ls-files failed (exit $rc)"
[ ! -s "$ART/FP_tracked.z" ] and stop ENUM "tracked-file inventory is empty"
```

**Evidence the condition would record:** `FP_tracked_lsfiles.exit` (already emitted),
`FP_STOPPED.txt` naming `ENUM`, the ledger row, and `FP_RUN_VERDICT.txt`.

The empty-list case is included because a zero exit with an empty inventory would otherwise produce
an empty manifest and a vacuous "no differences" result — a false pass.

## 5. Compatibility implications

| Aspect | Impact if approved |
|---|---|
| Stop-condition matrix | gains an 18th row; S1–S17 definitions **unchanged** |
| Reports | a new `ENUM` row may appear in `FP_ALL_CONDITIONS.tsv` |
| Existing evidence | **none**; v1–v4 packages are unaffected |
| Runner versions | v5 implements the trigger but the condition remains **unauthorized** until this proposal is ruled on |
| Gate semantics | none; `ENUM` is not a gate criterion |

## 6. Exact approval required

To activate `ENUM`, the governance authority must:

1. **Adopt** the condition text in §2 as an authorized stop condition, assigning it an ID;
2. **Confirm** the classification (environment/precondition) and that it is a fail-closed stop;
3. **Confirm** whether an empty-but-successful enumeration should also trigger it;
4. **Record** the decision in the canonical authorization packet.

Until all four are satisfied, `ENUM` remains `PROPOSED_NOT_AUTHORIZED`.

## 7. Current state of the code — stated plainly

The v5 runner **does implement the trigger** described in §4, because v4 already required a
distinct condition for this failure mode (A-5). **The trigger is present; the authorization is
not.** This is deliberate and reversible:

- If the authority rules that enumeration failure belongs to an existing ID, the label changes and
  nothing else does.
- If the authority rejects the condition entirely, the trigger is removed.
- **No packet text has been edited** to make this proposal appear approved, and no identifier has
  been silently mapped onto S6 or S17.

---

**ENUM is proposed, not authorized.** Runtime validation remains unauthorized.