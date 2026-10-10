# RAPHAEL G3 — v7 Targeted Remediation: Handoff

**Prepared:** 2026-10-10
**Implementation agent:** RAPHAEL — Space Bunny
**Independent auditor:** RAPHAEL-Auditor — DeepSeek V4.1 (review **not yet performed**)
**Root:** `/home/yaser/audit-rsi1/g3-remediation-v7-20261010/`

**Pre-flight verified:** baseline `fc3e2c132591eab7edaa12e97e13fe2d01619411` / tree
`e24d42bf7f7655293f3eb3a273c9ce4d94b1e061`; v6 manifest reproduced a real `sha256sum -c` FAILURE
(E-5 evidence); v7 destination confirmed absent before creation.

**Governance:** S5 pending · S10 ceiling recorded (2700 s), **execution unauthorized** · ENUM
**proposed, not authorized** · C8 unresolved · §14.12 outstanding · **G3 NOT ACCEPTED** ·
P4/P10 NOT AUTHORIZED · runtime validation **not authorized**.

> **The v7 runner has NEVER been executed.** `bash -n`, isolated tests, and checksum verification
> are **not** runtime validation.

---

## 1. E-5 — Manifest-generation ordering: **CORRECTED** (reproduced first)

**Auditor's finding reproduced against the actual v6 package before any change:**

```
$ cd g3-remediation-v6-20261010 && sha256sum -c <(grep -v '^#' HANDOFF_MANIFEST_V6_20261010.md)
validation/manifest_inventory_check.txt: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
```

**Root cause.** The v6 script generated the manifest (hashing the then-current reconciliation
file), then **rewrote** `manifest_inventory_check.txt` and created `.disk.tmp`/`.mani.tmp` inside
the same directory it was inventorying. The digest was therefore stale by construction.

**v7 deterministic generation order** (implemented in `capture_validation_and_manifest.sh`):

| Step | Action |
|---|---|
| 1 | static validation (`bash -n`) + isolated tests |
| 2 | write final `NOT_VALIDATED.txt` |
| 3 | create **all** working files in a `mktemp -d` **outside** the package |
| 4 | take the **final** on-disk inventory (no temps inside the package) |
| 5 | write `manifest_inventory_check.txt` to its **final** content — never rewritten after |
| 6 | generate the checksum manifest **last**, covering every file except itself |
| 7 | **actually run** `sha256sum -c` and record the real matched/mismatched totals |

The reconciliation file is finalized **before** the manifest hashes it, so its recorded digest is
valid. The manifest self-excludes (documented). Integrity is asserted **only** because the real
`sha256sum -c` reported it — not because generation completed.

## 2. E-6 — Complete the artifact-protection boundary: **CORRECTED**

v6 `PROTECTED_LOCATIONS` listed repo + frozen v1 + v2/v3/v4 but **omitted v5 and v6**. v7 now
protects, in addition: the v5 package (`g3-remediation-decisions-20261010`), the v6 package
(`g3-remediation-v6-20261010`), and the **current v7 package** (`g3-remediation-v7-20261010`).

**Both containment directions** are preserved and now operate on **normalized** paths. A
`norm_path` helper collapses repeated slashes, strips trailing `/`, and removes interior `/./`
segments, so a trailing-slash or relative-path spelling cannot evade the prefix test:

```
Direction 1: ART inside (or equal to) a protected location  -> STOP
Direction 2: a protected location inside (or equal to) ART  -> STOP
```

Boundary checks run **before** any directory creation or evidence write. **S15** remains an
independent guard against a non-empty destination. Future execution artifacts use fresh paths
(`g3-floor-wt-v7` / `g3-floor-artifacts-v6`→`-v7`); those directories are **not created here**.

## 3. E-7 — Stale ENUM proposal reference: **CORRECTED**

The v6 runner cited `decisions/ENUM_PROPOSAL_20261010.md`, which was **absent** from the v6
package — a dangling reference (verified: v6 `decisions/` held only the JSON, the `.md`, and the
validator). v7 **carries the proposal in-package** at `decisions/ENUM_PROPOSAL_20261010.md` with
a v7 provenance note; the reference now resolves. The copy remains
**`PROPOSED_NOT_AUTHORIZED`** — copying it does **not** activate ENUM, grant it authorized status,
or modify the canonical authorization packet. This is **documentation-only**; the runner still does
not enforce ENUM. A whole-file search confirms no stale current-version paths or runner identity
strings remain in v7 artifacts (all remaining `v4`/`v6` mentions are historical narration).

## 4. E-7b / E-8 — Accurate inventory counts: **CORRECTED**

v6 recorded `disk=16` while listing a stale `.disk.tmp`, and omitted explicit accounting of the
self-excluded manifest. v7:

- takes the inventory **after** temp-file cleanup (temps live outside the package, so they can
  never appear);
- **computes** counts from the real directory — nothing is hardcoded;
- distinguishes **total files on disk**, **manifest entries**, and **documented control-file
  exclusions** (the manifest's self-reference is explained, not treated as a missing file);
- reconciles the handoff, the reconciliation file, and the manifest.

## 5. Preserved v6 controls (unchanged while fixing integrity)

| Control | State |
|---|---|
| S10 ceiling | **2700 s** (separate from the 1200 s E-2 minimum) |
| E-2 minimum | **1200 s**, separate, unchanged |
| S5 expected digest | **unpinned / unresolved** |
| S16 | `.venv` **included** in both repo and worktree scans (INCLUDE_VENV) |
| S17 | literal marker retained; **S6** carries the actual scope-mismatch failure |
| ENUM | **not an authorized condition**; enumeration failure → `die_internal` (fail-closed, INTERNAL) |
| `runtime_validation_authorized` | **false** |
| Runtime paths | fresh, version-specific (`g3-floor-wt-v7` / `g3-floor-artifacts-v7`) |

## 6. Validation performed vs not performed

**Performed — static and isolated only; the runner was never executed:**

| Check | Result |
|---|---|
| Reproduce v6 E-5 failure (`sha256sum -c` on v6 manifest) | **1 FAILED** (`manifest_inventory_check.txt`) — confirms the defect |
| `bash -n` on the v7 runner | **exit 0** (syntax only) |
| Isolated tests (real `validate_decisions.py` + shipped guard), run against **v7** | **24/24 PASS** |
| v7 decisions JSON validates (ceiling 2700, minimum 1200, S5 null, ENUM false, rva false) | confirmed |
| v7 E-6 / E-7 static checks (protected list, normalized containment, reference resolves) | confirmed |
| **`sha256sum -c` on the completed v7 package** | see `validation/manifest_verify_summary.txt` for the **actual** matched/mismatched totals and full output |

**Not performed (runtime):** the v7 runner has **never been executed**. No guard, phase, timeout,
fail-closed path or decision-consumption path is runtime-proven. No floor suite, benchmark, or
application code. `shellcheck` unavailable. Failure paths were **not** provoked through the runner.
**Static checks and checksum verification do not prove runner behavior at runtime.**

## 7. Preservation of v1–v6 and repository state

| Item | Status |
|---|---|
| Frozen v1 `g3-floor-artifacts` | **UNMODIFIED** (`SHA256SUMS` `83a73f6e…`, 0 mismatches) |
| v2 / v3 / v4 / v5 / v6 packages | **UNMODIFIED** — runners `2d920321…`, `53810acf…`, `2ab038a5…`, `ccddb07d…`, `02df9177…` |
| Repository | **UNCHANGED** — HEAD `fc3e2c132…`, 14 status entries, 4 worktrees |

No commit, push, merge, tag, reset, clean, restore, stash, branch switch, or worktree add/remove.
v7 was built by copying v6; v6 files were not edited.

## 8. Remaining blockers and required approvals

| # | Item | Status |
|---|---|---|
| 1 | **S5 expected digest** | **BLOCKING** — observed `a23b7156…` retrieved, **not pinned** |
| 2 | **ENUM authorization** (four-part) | **proposed, not authorized**; runner does not enforce it |
| 3 | **C8** independent review | unresolved |
| 4 | **§14.12 GLM adversarial review** | outstanding |
| 5 | **G3 / P4 / P10** | not accepted / not authorized |
| 6 | **Runtime validation** | **not authorized** |

---

**No implementation report can accept its own work, and none is claimed here. No runtime floor run
was executed and no audit is claimed to have occurred.** Ready for a fresh read-only DeepSeek V4.1
audit. Sequence: implementation → evidence → independent audit → governance decision →
separately authorized runtime validation, if approved.