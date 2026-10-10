# RAPHAEL G3 v8 — Findings Disposition Matrix (QW-01 … QW-06)

**Baseline:** `7851bf151a7fa4b05cad618509697e84ff5b05da` (branch `audit/qwen-g3-v7-20261010`)
**Candidate branch:** `remediation/g3-v8-qw01-qw02-qw04-20261010`
**Package:** `audit-snapshots/g3-remediation-v8-20261010/`

**The v7 publication is immutable and was not modified.**

| ID | Severity | Finding | Disposition | Implementation | Evidence |
|---|---|---|---|---|---|
| **QW-01** | CRITICAL | S14 `norm_path()` had a malformed parameter expansion appending the literal `        }` to every path; `/./` was collapsed incorrectly and `..` was never resolved, so `<protected>/../<protected>/evil` escaped the containment test | **FIXED** | `g3_norm_path` / `g3_s14_boundary_violation` in `g3_v8_lib.sh` canonicalize with `realpath -m` (resolves `..`, `/./`, repeated/trailing separators, symlinks, non-existent tails) and **fail closed** when canonicalization is unavailable. The runner's inline `norm_path()` is removed and replaced by a library call | `test_v8_regressions.sh` QW-01 block: 9 canonicalization cases + 5 containment cases incl. the **`..` traversal regression**, all PASS. The v7 bypass was reproduced first (`norm_path` output ended `        }`, traversal reported "DID NOT STOP") |
| **QW-02** | HIGH | S7 extracted the observed unreadable set with a regex matching only `No such file or directory`; permission-denied, I/O and symlink-loop failures were silently dropped, allowing a false integrity PASS | **FIXED** | `g3_hash_account` computes the **complete** unhashed set as (tracked NUL list − hashed manifest paths) from structured data, not error text. `g3_s7_set_equal` performs exact normalized set equality against the authorized literal. Applied on both BEFORE and AFTER sides | `test_v8_regressions.sh` QW-02 block: authorized case passes; three unexpected-failure categories each prevent a false PASS; missing authorized entry detected; missing inputs fail closed; spaced filename accounted. 10 cases PASS |
| **QW-04** | HIGH | Validator emitted Python `True`; loader compared `!= "True"` (passed) but `scan_fpstar` compared `= "true"` (failed), so a valid INCLUDE_VENV decision deterministically aborted the run after artifact creation | **FIXED** | `g3_norm_bool` normalizes `True/true`→`true`, `False/false`→`false`, ambiguous→fail closed, applied **once** at the validator/shell boundary. `scan_fpstar` and the loader now share one representation. `runtime_validation_authorized` is additionally asserted `false` | `test_v8_regressions.sh` end-to-end: real validator output (`True`) → `g3_norm_bool` → scan branch `true`. Demo confirms v7 aborts where v8 proceeds. `test_v8_decisions.sh` preserves S5/S10/S16/S17/ENUM coverage |
| **QW-06** | MEDIUM | Tests relied on source-text searches, hard-coded `/home/yaser/...` paths, and a re-declared S10 guard; no coverage for S14/S7/S16 | **FIXED** | New `g3_v8_lib.sh` is sourced by **both** the runner and the tests, so controls are exercised as production code. Tests derive paths from `BASH_SOURCE`; the interpreter is overridable via `G3_TEST_PYTHON`. Fixtures live in `mktemp -d` and are removed on exit | `test_v8_regressions.sh` (30/30) + `test_v8_decisions.sh` (17/17). No authoring-machine path is hard-coded; `grep` of the test files confirms zero `/home/yaser` literals |
| **QW-03** | LOW (contract) | `AUTHORIZED_UNREADABLE_SHA256` is displayed but unused for enforcement; Qwen's raw-diff false-success claim was overstated | **PARTIALLY FIXED — contract aligned; governance input required** | The digest is now explicitly **descriptive**: `g3_s7_descriptive_digest` is documented as a human-facing fingerprint and is **never** an enforcement input. Enforcement is exact set equality (`g3_s7_set_equal`) plus the unchanged raw before/after stderr diff, which still detects changes independently | `test_v8_regressions.sh` QW-03 block: digest is stable and labelled descriptive. **The governing question — whether S7 is normatively digest-based, set-based, or diff-based — is not settled by the packet and is referred for operator decision** |
| **QW-08** | LOW | Unchecked evidence-ledger writes and unchecked final ledger copy; no demonstrated false-success path | **NOT FIXED (deferred)** | Not attempted. The task permits this only as bounded, separately-tested hardening **after** the three primary defects, and no false-success path was demonstrated | Not addressed in v8. Referred |
| **QW-09** | — | Not confirmed as a defect | **NOT FIXED (no evidence)** | Timeout/termination classification left unchanged, per instruction not to alter without concrete evidence | Not addressed |

## Summary

- **FIXED:** QW-01, QW-02, QW-04, QW-06
- **PARTIALLY FIXED:** QW-03 (implementation aligned; governing interpretation unresolved)
- **NOT FIXED / deferred:** QW-08 (no demonstrated failure path), QW-09 (unconfirmed)

## Open specification question (QW-03)

The authorization packet states the correct S7 check is that the unreadable record "names exactly
those 4" **and** that the before/after diff is clean. That is consistent with the implemented
set-equality + raw-diff behaviour. It does **not** mandate digest-based authorization. Because the
documents do not unambiguously fix the normative basis, v8 aligns terminology and labels the digest
as descriptive rather than inventing an authorization rule. **Operator decision requested.**

## Governance

Unchanged: G3 NOT ACCEPTED · P4/P10 NOT AUTHORIZED · S5 unpinned · ENUM
PROPOSED_NOT_AUTHORIZED · C8 unresolved · §14.12 GLM review outstanding · runtime validation NOT
authorized. S10 ceiling remains 2,700 s; E-2 minimum remains 1,200 s. No decision was changed to
make a test pass.