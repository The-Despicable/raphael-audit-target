#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 TEST-FLOOR RUNNER — v7 INTEGRITY
# =============================================================================
# Successor to v6. v1..v6 and all frozen evidence are NOT replaced or modified.
#
# v7 CHANGES (this pass — audit findings E-5 .. E-8):
#
#   E-5  Artifact-integrity generation order (this file's own package tooling).
#        The v6 package's manifest recorded a digest for
#        validation/manifest_inventory_check.txt and then REWROTE that file, so
#        `sha256sum -c` reported FAILED for it. v7 tooling writes the
#        reconciliation to its FINAL content first, then generates the manifest
#        over the finalized set, then actually runs `sha256sum -c` and records
#        the real result. Integrity is never claimed merely because generation
#        completed.
#
#   E-6  PROTECTED_LOCATIONS now includes the v5 and v6 remediation packages and
#        the current v7 package, in addition to the repository, frozen v1
#        evidence and v2/v3/v4. Both containment directions are checked on
#        NORMALIZED paths, so a trailing slash, doubled separator or "/./"
#        segment cannot evade the boundary. S15 remains an independent guard.
#
#   E-7  The v6 runner cited decisions/ENUM_PROPOSAL_20261010.md, which was
#        absent from the v6 package (a dangling reference). v7 carries the
#        proposal in-package, still marked PROPOSED_NOT_AUTHORIZED. Copying it
#        does NOT activate ENUM or modify the canonical authorization packet.
#
#   E-8  Inventory counts are taken from the FINAL directory state, after
#        temporary files are removed to a location OUTSIDE the package, and are
#        reconciled against the manifest. Counts are computed, never hardcoded.
#
# v7 also moves runtime defaults to fresh, version-specific paths
# (g3-floor-wt-v7 / g3-floor-artifacts-v7) and stamps runner_version=v7-integrity.
#
# PRIOR PASSES PRESERVED:
#   E-1..E-4 (v6): S10 env-capture ordering fixed; genuine strict-JSON decision
#   artifact validated by a shared Python validator; fresh runtime paths; correct
#   version provenance. A-1..A-10 (v4), F-1/F-2 (v2), B-1..B-4 (v5) also hold.
#
# DECISIONS PRESERVED UNCHANGED (not reinterpreted while fixing integrity):
#   S10 ceiling 2700 s; E-2 minimum 1200 s (separate); S5 digest unpinned;
#   S16 INCLUDE_VENV for both roots; S17 literal marker retained with S6 as the
#   actual scope-failure carrier; ENUM not an authorized condition (enumeration
#   failure uses die_internal); runtime_validation_authorized=false.
#
# GOVERNANCE: this runner does not accept G3 and does not authorize P4 or P10.
# RUNTIME STATUS: this runner has NEVER been executed. bash -n proves it parses
# and nothing more. No guard below is demonstrated behaviour.
# This file does NOT replace or modify v1..v5, or any frozen evidence.
#
# Lineage (all immutable, none modified by this file):
#   v1  g3-floor-artifacts/g3-floor-run.sh
#       sha256 2b87e9f5e0a33841586026209ae8a539f051f7926ec638e4413cd45f01b739d4
#   v2  g3-floor-run-v2-hardened.sh
#       sha256 2d920321f9a609fb065a52fab161851596e00024598a04e8a9eb3944726f0ffc
#   v3  g3-floor-run-v3-hardened.sh
#       sha256 53810acfd89440addf1c40631b2e7d140520a2075e8a9b68e27d514feea7b4db
#   v4  g3-floor-run-v4-hardened.sh
#       sha256 2ab038a5a41ec37aa68ce0538c066bfe3d201862ed5faf75541b7ad623358bfb
#   v5  g3-floor-run-v5-configured.sh
#       sha256 (in g3-remediation-decisions-20261010/HANDOFF_MANIFEST_DECISIONS_20261010.md)
#   v6  this file  (g3-floor-run-v6-validated.sh)
#
# Authorized definitions: reports/product-readiness/g3-remediation/
#   G3_TEST_FLOOR_AUTHORIZATION_REQUEST_20261009.md  section 8, lines 570-596
#   G3_TEST_FLOOR_AUTHORIZATION_REQUEST_20261009.json stop_conditions[]
# Baseline identity: unchanged from v1, v2 and v3.
#
# ---------------------------------------------------------------------------
# FINDING DISPOSITIONS (A-1 .. A-10)
#
# A-1  S17 was unreachable in v3: both manifests derive from one FP_tracked.z,
#      so the path-set comparison could not fire once S6 short-circuited.
#      v4 restores the AUTHORIZED LITERAL S17 check and makes it reachable in
#      BOTH branches without weakening S6:
#        * unequal scope -> S6 writes the SCOPE_MISMATCH marker, S17 asserts the
#          marker is PRESENT (the authorized condition is satisfied);
#        * equal scope   -> S17 asserts the marker is ABSENT (violation if present).
#      S6 is unchanged. The path-set comparison is retained as an ADDITIONAL
#      diagnostic (records S17_PATHCHECK), not as the S17 trigger.
#
# A-2  v3 took the worktree FP_* baseline BEFORE `git worktree add`, so the
#      baseline was captured from a path that did not yet exist. v4 moves the
#      worktree baseline to immediately after worktree creation and identity
#      verification, and records the repository baseline separately.
#
# A-3  v3 called `finalize SUCCESS` on S6 scope mismatch, skipping S8 verify,
#      S13 and S16 - all independent of manifest scope. v4 records S6 and
#      CONTINUES: only the hash diff (which depends on equal scope) is skipped.
#      Worktree cleanliness, artifact isolation and manifest re-verification
#      still run. Non-zero status is preserved by the ledger.
#
# A-4  v3 documented FP_all_exit_codes.txt as 13 lines and justified it as
#      "1 header + 3 x 4"; the construction actually emits 4 header lines plus
#      3 x (1 format marker + 3 record lines) = 16. v4 emits and documents 16,
#      and the runner self-checks the emitted count against the header.
#
# A-5  v3 relabelled `git ls-files` failure as S17. That repurposed S17 and is
#      withdrawn. Enumeration failure is now its own condition (ENUM) and the
#      classification question is referred to governance.
#
# A-6  v3's decision table described STOP as exiting 1, but the ledger could
#      escalate an intent to a higher code. v4 documents the ACTUAL control
#      flow: the caller supplies a MINIMUM severity and the ledger raises it.
#      The implementation was already fail-closed and is NOT altered; only the
#      documentation is corrected to match.
#
# A-7  v3 set EXECUTION_STARTED=1 before COLLECTION and called collection
#      "pre-execution" in places. v4 uses four distinct phase names:
#      PREFLIGHT -> COLLECTION -> SUITE -> POST-RUN, with separate markers, and
#      documentation that matches.
#
# A-8  v3's S14 guard refused ART inside REPO/WT and two specific evidence
#      paths, but did not protect the v2/v3 remediation directories. v4 refuses
#      ART inside ANY protected location by an explicit list, and does not rely
#      on S15 emptiness as a substitute for the boundary check.
#
# A-9  v3's NOT_VALIDATED.txt labelled the unreadable-set check "S2". It is S7.
#      v4 corrects the label and points at the correct evidence files.
#
# A-10 v3 verified symlink blob hashes only on the BEFORE side. v4 also
#      re-verifies them AFTER the run, so a symlink replaced mid-run is caught
#      even when the unreadable name set is unchanged.
#
# Additional control-flow requirement (timeout/environment routing):
#      v4 routes TIMEOUT to S10 when a ceiling is armed and to S11 otherwise,
#      uniformly across COLLECTION, SUITE and GUARDRAIL. S12 remains explicitly
#      pattern-based; that limitation is documented, not papered over.
#
# GOVERNANCE: this runner does not accept G3 and does not authorize P4 or P10.
# RUNTIME STATUS: this runner has NEVER been executed. bash -n proves it parses
# and nothing more. No guard below is demonstrated behaviour.
# =============================================================================

set -uo pipefail
# Deliberately NOT `set -e`. Strict mode is not a control. Every guard below is
# an explicit test with an explicit failure path.

REPO="${G3_REPO:-/home/yaser/external-audits/raphael-2}"
# E-3: v6 uses FRESH, versioned default paths. v5 wrongly reused the v4 defaults
# (g3-floor-wt-v4 / g3-floor-artifacts-v4), which would collide with any prior
# v4 run's locations. These are FUTURE EXECUTION paths; the runner does not
# create them here, and neither does this remediation.
WT="${G3_WT:-/home/yaser/audit-rsi1/g3-floor-wt-v7}"
ART="${G3_ART:-/home/yaser/audit-rsi1/g3-floor-artifacts-v7}"
PY="$REPO/.venv/bin/python"

EXPECT_HEAD=fc3e2c132591eab7edaa12e97e13fe2d01619411
EXPECT_TREE=e24d42bf7f7655293f3eb3a273c9ce4d94b1e061

# A-8 / B-2 / E-6: explicit protected locations. ART may not be inside any of these,
# nor may it BE any of them. This is a boundary check in its own right; it is
# not a substitute for, and is not substituted by, the S15 emptiness check.
#
# E-6: v6 omitted the v5 and v6 remediation directories. All earlier remediation
# packages, the frozen v1 evidence, the repository, AND the current v7 package are
# now protected. Protection is the correct boundary check because S15 only
# refuses a NON-EMPTY directory, so an empty pointer inside one would not stop.
PROTECTED_LOCATIONS="/home/yaser/external-audits/raphael-2
/home/yaser/audit-rsi1/g3-floor-artifacts
/home/yaser/audit-rsi1/g3-remediation-f01-f02-20261010
/home/yaser/audit-rsi1/g3-remediation-audit-findings-20261010
/home/yaser/audit-rsi1/g3-remediation-audit-round3-20261010
/home/yaser/audit-rsi1/g3-remediation-decisions-20261010
/home/yaser/audit-rsi1/g3-remediation-v6-20261010
/home/yaser/audit-rsi1/g3-remediation-v7-20261010"

# S4: authorized interpreter range: >=3.11,<3.13
PY_MIN_MAJOR=3; PY_MIN_MINOR=11
PY_MAX_MAJOR=3; PY_MAX_MINOR=13

# ---------------------------------------------------------------------------
# F-2 / A-10: EXACT authorized unreadable set and its baseline symlink blobs.
#
# Source of truth:
#   Packet MD line 247 and lines 594-596:
#     "4 tracked symlinks (cai_service, cloak_service, mcp_hub, mhddos_service
#      -> /home/yaser/raphael-2.0/..., absent) are unreadable by sha256sum"
#     "the correct check is that FP_BEFORE_unreadable.txt names exactly those 4
#      and that FP_unreadable_diff.exit is 0"
#   Packet JSON lines 361-362 (correct_check) state the same.
#
# The expected set is a LITERAL CONSTANT here. It is deliberately NOT read from
# FP_BEFORE_unreadable.txt or any file the run produces: those are observations
# under test, not their own authority.
# ---------------------------------------------------------------------------
AUTHORIZED_UNREADABLE="cai_service cloak_service mcp_hub mhddos_service"
AUTHORIZED_SYMLINK_BLOBS="cai_service=6fcf4f90d3e3cab66f9558763fd516664c2ba62a cloak_service=abb878ed534bd47c8c1bbd18ee9aa3ac5f6c101d mcp_hub=4605b22654c89198b40c4769d91b14d95acb0b8d mhddos_service=190d568ffdbaab8fd19365ccd815044bbee7622a"

# S5: the packet fixes the inventory METHOD but pins no expected digest.
# The runner NEVER pins the observed value itself. It is populated only if the
# operator has recorded an approved expected digest in the decision artifact.
EXPECT_PACKAGES_DIGEST="${EXPECT_PACKAGES_DIGEST:-}"

# ---------------------------------------------------------------------------
# v6: OPERATOR DECISION ARTIFACT — authoritative configuration source.
#
# E-2: the decision data now lives in a GENUINE strict-JSON file and is parsed by
# decisions/validate_decisions.py (Python stdlib json), not by fragile regex.
# The validator fails closed on missing, malformed, wrongly-typed or internally
# inconsistent fields. The old Markdown artifact is preserved and REJECTED.
#
# E-1: the incoming environment value is captured HERE, at the very top, BEFORE
# any reset or reassignment of S10_CEILING_SECONDS. In v5 the variable was reset
# to "" at declaration and the "env" copy was taken afterwards, so the conflict
# guard could never observe a real override (dead code). Capture order matters:
#   1. capture incoming env value        (S10_CEILING_SECONDS_ENV)
#   2. load + validate decision artifact (authoritative 2700)
#   3. apply the conflict rule to (1) vs (2)
#
# The 20-minute E-2 MINIMUM is preserved as a DISTINCT requirement and is never
# reinterpreted as the maximum.
# ---------------------------------------------------------------------------
DECISIONS_FILE="${G3_DECISIONS_FILE:-/home/yaser/audit-rsi1/g3-remediation-v7-20261010/decisions/G3_OPERATOR_DECISIONS_V7.json}"
DECISIONS_VALIDATOR="${G3_DECISIONS_VALIDATOR:-/home/yaser/audit-rsi1/g3-remediation-v7-20261010/decisions/validate_decisions.py}"

# E-2 minimum (existing, unchanged) — a FLOOR on available time, recorded as a
# separate fact. It is NOT the ceiling.
E2_MINIMUM_BUDGET_SECONDS=1200

# E-1 (step 1): capture the incoming environment value IMMEDIATELY, before any
# reset below. Do not move this later; doing so was the v5 defect.
S10_CEILING_SECONDS_ENV="${S10_CEILING_SECONDS:-}"

# Populated by load_decisions():
S10_CEILING_SECONDS=""
S16_SCAN_INCLUDES_VENV=""
RUNTIME_VALIDATION_AUTHORIZED=""

load_decisions() { # must run before any artifact creation; fails closed
  if [ ! -f "$DECISIONS_FILE" ]; then
    say "STOP: DECISION ARTIFACT MISSING: $DECISIONS_FILE" >&2
    exit 1
  fi
  if [ ! -f "$DECISIONS_VALIDATOR" ]; then
    say "STOP: DECISION VALIDATOR MISSING: $DECISIONS_VALIDATOR" >&2
    exit 1
  fi
  # E-2: parse + validate with the real Python json parser (shared with tests).
  local vout vrc
  vout="$("$PY" "$DECISIONS_VALIDATOR" "$DECISIONS_FILE" 2>&1)"
  vrc=$?
  if [ "$vrc" -ne 0 ]; then
    say "STOP: DECISION ARTIFACT INVALID: $(printf '%s' "$vout" | tr '\n' ';')" >&2
    exit 1
  fi
  # Extract validated scalars from the validator's key=value output.
  S10_CEILING_SECONDS="$(printf '%s\n' "$vout" | sed -n 's/^s10_ceiling_seconds=//p')"
  S16_SCAN_INCLUDES_VENV="$(printf '%s\n' "$vout" | sed -n 's/^s16_scan_includes_venv=//p')"
  RUNTIME_VALIDATION_AUTHORIZED="$(printf '%s\n' "$vout" | sed -n 's/^runtime_validation_authorized=//p')"
  if [ -z "$S10_CEILING_SECONDS" ] || [ "$S10_CEILING_SECONDS" != "2700" ]; then
    say "STOP: validator did not yield the approved ceiling 2700 (got '$S10_CEILING_SECONDS')" >&2
    exit 1
  fi
  if [ "$S16_SCAN_INCLUDES_VENV" != "True" ]; then
    say "STOP: validator did not yield S16 INCLUDE_VENV (got '$S16_SCAN_INCLUDES_VENV')" >&2
    exit 1
  fi
}

# E-1 (step 3): the environment variable is NOT a silent override. If it was
# non-empty it must exactly equal the approved ceiling; anything else fails
# closed. An unset or empty value is accepted (the decision stands alone).
check_s10_env_not_conflicting() { # approved_seconds
  local approved="$1"
  if [ -n "$S10_CEILING_SECONDS_ENV" ] && [ "$S10_CEILING_SECONDS_ENV" != "$approved" ]; then
    say "STOP: S10 env override S10_CEILING_SECONDS='$S10_CEILING_SECONDS_ENV' conflicts with approved ceiling '$approved'; refusing to substitute" >&2
    exit 1
  fi
  if [ -n "$S10_CEILING_SECONDS_ENV" ]; then
    say "S10 env override '$S10_CEILING_SECONDS_ENV' matches the approved ceiling"
  else
    say "S10 env override unset/empty; the approved decision value is authoritative"
  fi
  return 0
}

# Explicit operator waivers. Never set by default. A waiver lets the run
# proceed but the condition is still recorded as BLOCKED_WAIVED.
ALLOW_UNENFORCED_S5="${ALLOW_UNENFORCED_S5:-0}"
ALLOW_UNENFORCED_S10="${ALLOW_UNENFORCED_S10:-0}"

ART_ABS=""
LEDGER=""
FINALIZED=0
PHASE="INIT"

# A-7: four distinct phase markers. Collection is NOT part of test execution.
PHASE_PREFLIGHT_DONE=0
PHASE_COLLECTION_DONE=0
PHASE_SUITE_DONE=0

say() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

record() { # id status detail
  [ -n "$LEDGER" ] && printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$LEDGER"
  return 0
}

# ---------------------------------------------------------------------------
# A-6: the final exit status is DERIVED FROM THE LEDGER.
#
# The caller supplies a MINIMUM severity via finalize(). The ledger can only
# RAISE it. Success (0) is reachable only when:
#   (a) the caller passed SUCCESS, AND
#   (b) the ledger holds zero FAIL rows, AND
#   (c) the ledger holds zero BLOCKED (unwaived) rows.
# A later finalize() call therefore cannot mask an earlier failure.
#
# This is the v3 behaviour, unchanged and still fail-closed. Only the DOCUMENTED
# semantics are corrected here (A-6): intent is a floor, not a ceiling.
# ---------------------------------------------------------------------------
ledger_count() { # status -> count
  local n
  n=$(grep -c $'\t'"$1"$'\t' "$LEDGER" 2>/dev/null) || n=0
  [ -z "$n" ] && n=0
  printf '%s' "$n"
}

finalize() { # min_severity reason   SUCCESS | STOP | BLOCKED | INTERNAL
  [ "$FINALIZED" -eq 1 ] && return 0
  FINALIZED=1

  local nfail nblocked nwaived sev
  nfail=$(ledger_count FAIL)
  nblocked=$(ledger_count BLOCKED)
  nwaived=$(ledger_count BLOCKED_WAIVED)

  case "$1" in
    SUCCESS)  sev=0 ;;
    STOP)     sev=1 ;;
    BLOCKED)  sev=2 ;;
    INTERNAL) sev=3 ;;
    *)        sev=3 ;;
  esac

  # Ledger escalates only.
  [ "$nfail"    -gt 0 ] && [ "$sev" -lt 1 ] && sev=1
  [ "$nblocked" -gt 0 ] && [ "$sev" -lt 2 ] && sev=2

  local verdict
  case "$sev" in
    0) verdict="PASS" ;;
    1) verdict="FAIL" ;;
    2) verdict="BLOCKED" ;;
    3) verdict="INTERNAL_ERROR" ;;
    *) verdict="INTERNAL_ERROR" ;;
  esac

  {
    printf 'runner_version=v7-integrity\n'
    printf 'finalized_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'caller_min_severity=%s\n' "$1"
    printf 'derived_exit_code=%s\n' "$sev"
    printf 'verdict=%s\n' "$verdict"
    printf 'reason=%s\n' "${2:-none}"
    printf 'phase_preflight_done=%s\n' "$PHASE_PREFLIGHT_DONE"
    printf 'phase_collection_done=%s\n' "$PHASE_COLLECTION_DONE"
    printf 'phase_suite_done=%s\n' "$PHASE_SUITE_DONE"
    printf 'conditions_fail=%s\n' "$nfail"
    printf 'conditions_blocked_unwaived=%s\n' "$nblocked"
    printf 'conditions_blocked_waived=%s\n' "$nwaived"
    printf 'exit_code_contract=0=PASS 1=STOP_CONDITION_VIOLATED 2=BLOCKED_AUTHORIZATION 3=INTERNAL_ERROR\n'
    printf 'semantics=caller supplies a MINIMUM severity; the ledger may only RAISE it\n'
    printf 'runtime_validation_status=NEVER_EXECUTED; bash -n only; no guard is proven at runtime\n'
    printf 'governance_g3=NOT_ACCEPTED\n'
    printf 'governance_p4=NOT_AUTHORIZED\n'
    printf 'governance_p10=NOT_AUTHORIZED\n'
    printf 'note=runner verdict describes RUN VALIDITY only; it is NOT gate acceptance\n'
  } > "$ART/FP_RUN_VERDICT.txt"

  cp -f "$LEDGER" "$ART/FP_ALL_CONDITIONS.tsv"
  say "FINAL VERDICT: $verdict (min=$1 exit=$sev fail=$nfail blocked=$nblocked waived=$nwaived)"
  exit "$sev"
}

# Immediate abort. Used only where continuing would be unsafe or meaningless.
# Pass the MINIMUM severity; the ledger may raise it.
stop() { # condition_id detail
  record "$1" FAIL "$2"
  printf 'STOP %s: %s\nstopped_utc=%s\nphase=%s\n' \
    "$1" "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PHASE" > "$ART/FP_STOPPED.txt"
  say "STOP: $1 — $2" >&2
  finalize STOP "stop:$1"
}

# Record a violation WITHOUT aborting so remaining safe checks still run.
violate() { # condition_id detail
  record "$1" FAIL "$2"
  say "VIOLATION: $1 — $2" >&2
  return 0
}

# Pre-execution refusal when a mandatory authorization value is absent.
preflight_refuse() { # condition_id detail
  record "$1" BLOCKED "$2"
  {
    printf 'PREFLIGHT REFUSAL\n'
    printf 'condition=%s\n' "$1"
    printf 'detail=%s\n' "$2"
    printf 'utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'phase=%s\n' "$PHASE"
    printf 'phase_suite_done=%s\n' "$PHASE_SUITE_DONE"
    printf 'floor_ran=NO\n'
    printf 'note=No test was collected, executed or measured. This is not a floor result.\n'
  } > "$ART/FP_PREFLIGHT_REFUSAL.txt"
  say "PREFLIGHT REFUSAL: $1 — $2" >&2
  finalize BLOCKED "preflight:$1"
}

die_internal() { # detail
  say "INTERNAL ERROR: $1" >&2
  [ -n "$ART_ABS" ] && [ -d "$ART_ABS" ] && printf 'INTERNAL_ERROR: %s\nphase=%s\n' "$1" "$PHASE" > "$ART_ABS/FP_INTERNAL_ERROR.txt"
  if [ -n "$LEDGER" ] && [ -f "$LEDGER" ]; then
    record INTERNAL FAIL "$1"
    finalize INTERNAL "internal:$1"
  fi
  exit 3
}

# ---------------------------------------------------------------------------
# F-6: SINGLE writer for every *.exit record. All records share one format with
# exit=N as line 1 (v1-compatible). No other code path writes an FP_*.exit file.
# ---------------------------------------------------------------------------
write_exit_record() { # tag rc elapsed verdict
  printf 'exit=%s\nelapsed_seconds=%s\nverdict=%s\n' "$2" "$3" "$4" > "$ART/FP_$1.exit"
}

# S12 is explicitly PATTERN-BASED. This is a known limitation: an environmental
# fault whose text does not match will be classified FAILURE. Streams are kept
# verbatim so a reviewer can audit every classification.
classify_rc() { # rc stdout stderr
  local rc="$1" out="$2" err="$3"
  if [ "$rc" -eq 0 ]; then echo "EXIT_0"; return; fi
  if [ "$rc" -eq 124 ]; then echo "TIMEOUT"; return; fi
  if [ "$rc" -eq 137 ]; then echo "OOM_SUSPECTED"; return; fi
  if [ "$rc" -ge 128 ]; then echo "SIGNAL_$(( rc - 128 ))"; return; fi
  if grep -qiE 'ModuleNotFoundError|ImportError|could not import|ConnectionError|Network is unreachable|Temporary failure in name resolution|NameResolutionError|CUDA error|CUDA initialization|driver on your system is too old|OSError: \[Errno 111\]|SSL' "$out" "$err" 2>/dev/null; then
    echo "ENVIRONMENTAL"; return
  fi
  echo "FAILURE"
}

# Uniform timeout/environment routing across COLLECTION, SUITE and GUARDRAIL.
# TIMEOUT is a BUDGET event when a ceiling is armed (S10) and an environment
# event otherwise (S11). This routing is identical for all three phases.
route_phase_verdict() { # phase_tag rc verdict escalate
  local tag="$1" rc="$2" verdict="$3" escalate="$4"
  case "$verdict" in
    OOM_SUSPECTED)
      violate S11 "$tag phase OOM-killed (exit $rc); environment, NOT a test failure" ;;
    SIGNAL_*)
      violate S11 "$tag phase terminated by signal (exit $rc, verdict $verdict); environment, NOT a test failure" ;;
    TIMEOUT)
      if [ -n "$S10_CEILING_SECONDS" ]; then
        violate S10 "$tag phase hit the armed wall-clock ceiling (exit $rc)"
      else
        violate S11 "$tag phase timed out (exit $rc); no ceiling armed, so treated as environment"
      fi ;;
    ENVIRONMENTAL)
      violate S12 "$tag phase failed with an import/network/GPU cause (exit $rc); environment, NOT a test failure" ;;
  esac
  return 0
}

run_phase() { # tag cmd...
  local tag="$1"; shift
  local out="$ART/FP_$tag.out" err="$ART/FP_$tag.err"
  local rc start end elapsed verdict
  start=$(date +%s)
  ( cd "$WT" && "$@" ) > "$out" 2> "$err"
  rc=$?
  end=$(date +%s)
  elapsed=$(( end - start ))
  verdict="$(classify_rc "$rc" "$out" "$err")"
  write_exit_record "$tag" "$rc" "$elapsed" "$verdict"
  record "P_$tag" INFO "$tag exit=$rc elapsed=${elapsed}s verdict=$verdict"
  say "phase $tag: exit=$rc elapsed=${elapsed}s verdict=$verdict"
  return 0
}

exit_field() { # tag field -> value
  sed -n "s/^$2=//p" "$ART/FP_$1.exit" | head -1
}

# =============================================================================
PHASE="ARTIFACT_PRECONDITIONS"
say "=== ARTIFACT PRECONDITIONS: decisions, S14 boundary, S15 emptiness ==="
# -----------------------------------------------------------------------------
# v6: load and validate the operator decision artifact BEFORE creating any
# artifact directory. A missing/malformed/inconsistent decision is a hard stop.
# E-1: S10_CEILING_SECONDS_ENV was captured at the TOP of the script (before any
# reset). Do NOT re-capture it here; that late capture was the v5 defect.
load_decisions
check_s10_env_not_conflicting "$S10_CEILING_SECONDS"
say "decisions loaded: S10 ceiling=${S10_CEILING_SECONDS}s (E-2 minimum=${E2_MINIMUM_BUDGET_SECONDS}s unchanged), S16 venv=${S16_SCAN_INCLUDES_VENV}, runtime_validation_authorized=${RUNTIME_VALIDATION_AUTHORIZED:-UNKNOWN}"
# -----------------------------------------------------------------------------
# A-8 / B-2 / E-6: explicit boundary check against every protected location. ART
# must be outside REPO and WT, and must not be, nor lie inside, any protected
# evidence or remediation directory. This is independent of the S15 check.
#
# E-6 hardening: both operands are NORMALIZED before comparison, so that a
# trailing slash, a doubled separator or a "/./" segment cannot express the same
# path in a way that evades the prefix test. The boundary is NOT weakened.
norm_path() { # path -> canonical form for containment comparison
  local p="$1"
  p="${p//\/\///}"        # collapse repeated slashes
  while [ "$p" != "/" ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  p="${p//\/\.\/}        }"  # remove interior /./ segments
  [ -z "$p" ] && p="/"
  printf '%s' "$p"
}
for prot in $PROTECTED_LOCATIONS; do
  nprot="$(norm_path "$prot")"
  nart="$(norm_path "$ART")"
  # Direction 1: ART lies inside a protected location.
  if [ "$nart" = "$nprot" ] || case "$nart/" in "$nprot"/*) true ;; *) false ;; esac; then
    say "STOP: S14: ART ($ART) is inside or equal to protected location $prot" >&2; exit 1
  fi
  # Direction 2: a protected location lies inside ART.
  if [ "$nprot" = "$nart" ] || case "$nprot/" in "$nart"/*) true ;; *) false ;; esac; then
    say "STOP: S14: protected location $prot is inside or equal to ART" >&2; exit 1
  fi
done
say "S14 PASS: ART is outside every protected location (normalized comparison, both directions)"

# S15: refuse to overwrite a previous run's evidence.
if [ -e "$ART" ] && [ -n "$(ls -A "$ART" 2>/dev/null)" ]; then
  say "STOP: S15: ART exists and is non-empty; refusing to overwrite prior run evidence" >&2
  exit 1
fi
mkdir -p "$ART" || { say "STOP: cannot create ART" >&2; exit 1; }
ART_ABS="$ART"; LEDGER="$ART_ABS/FP_CONDITIONS.tsv"
: > "$LEDGER"
record P0 INFO "artifact directory created at $ART; S14 boundary verified against ${PROTECTED_LOCATIONS//$'\n'/ }"
say "S15 PASS: ART created empty at $ART"

FP="$ART/FP_start.txt"

# A-2: repository FP_* baseline may be taken now; the WORKTREE baseline is
# deferred until after the worktree exists (see the WORKTREE_BASELINE phase).
#
# v5 / S16 decision = INCLUDE_VENV: BOTH the repository and the worktree scans
# include the virtual environment. Only .git is excluded, and it is excluded
# identically for BOTH roots, so the two scans cannot drift apart. The decision
# is asserted here rather than assumed, so a missing decision is a hard stop
# (load_decisions already refused it) and an empty value cannot silently mean
# "exclude".
scan_fpstar() { # root outfile
  if [ "$S16_SCAN_INCLUDES_VENV" = "true" ]; then
    # INCLUDE_VENV: exclude .git only; .venv is IN scope for both roots.
    find "$1" -name 'FP_*' -not -path '*/.git/*' -print 2>/dev/null | sort > "$2"
  else
    say "STOP: S16 scan rule undetermined (decision not INCLUDE_VENV); refusing to guess" >&2
    exit 1
  fi
}
scan_fpstar "$REPO" "$ART/FP_FPSTAR_BASE_REPO.txt"

# =============================================================================
PHASE="BASELINE_IDENTITY"
say "=== BASELINE IDENTITY: S1, S2, S3 ==="
git -C "$REPO" rev-parse --show-toplevel > "$ART/FP_phase1_toplevel.txt" 2>&1 || stop S1 "rev-parse --show-toplevel failed"
git -C "$REPO" worktree list           > "$ART/FP_worktrees_pre.txt" 2>&1
git -C "$REPO" worktree add --detach "$WT" "$EXPECT_HEAD" > "$ART/FP_worktree_add.out" 2> "$ART/FP_worktree_add.err"
rc=$?; write_exit_record worktree_add "$rc" n/a GIT_WORKTREE_ADD
[ "$rc" -eq 0 ] || stop S1 "worktree add failed (exit $rc)"

git -C "$WT" rev-parse HEAD         > "$ART/FP_phase1_head.txt"  2>&1 || stop S1 "rev-parse HEAD failed"
git -C "$WT" rev-parse 'HEAD^{tree}' > "$ART/FP_phase1_tree.txt" 2>&1 || stop S2 "rev-parse HEAD^{tree} failed"
git -C "$WT" status --porcelain     > "$ART/FP_phase1_status.txt" 2>&1 || stop S3 "git status failed"

head_actual="$(cat "$ART/FP_phase1_head.txt")"
[ "$head_actual" != "$EXPECT_HEAD" ] && stop S1 "HEAD mismatch: got '$head_actual' want '$EXPECT_HEAD'"
record S1 PASS "worktree HEAD == $EXPECT_HEAD"

tree_actual="$(cat "$ART/FP_phase1_tree.txt")"
[ "$tree_actual" != "$EXPECT_TREE" ] && stop S2 "tree mismatch: got '$tree_actual' want '$EXPECT_TREE'"
record S2 PASS "worktree tree == $EXPECT_TREE"

[ -s "$ART/FP_phase1_status.txt" ] && stop S3 "worktree not clean at run start: $(head -5 "$ART/FP_phase1_status.txt" | tr '\n' ';')"
record S3 PASS "worktree clean at run start"
say "BASELINE IDENTITY PASS: S1, S2, S3 satisfied"

# =============================================================================
PHASE="WORKTREE_BASELINE"
say "=== WORKTREE BASELINE: S16 inventory of the ACTUAL worktree ==="
# -----------------------------------------------------------------------------
# A-2: v3 scanned $WT before `git worktree add`, so the baseline was captured
# from a path that did not yet exist. v4 takes BOTH baselines here, after the
# worktree exists and its identity is verified, so pre/post comparison observes
# the intended worktree.
#
# The comparison stays DIFFERENTIAL: an FP_* entry present in the baseline is
# pre-existing and is not a violation; only entries NEW at POST are violations.
scan_fpstar "$REPO" "$ART/FP_FPSTAR_PRE_REPO.txt"
scan_fpstar "$WT"  "$ART/FP_FPSTAR_PRE_WT.txt"
record S16_BASELINE INFO "baselines captured after worktree creation (repo=$(wc -l < "$ART/FP_FPSTAR_PRE_REPO.txt") wt=$(wc -l < "$ART/FP_FPSTAR_PRE_WT.txt"))"
say "S16 baseline captured after worktree creation (repo=$(wc -l < "$ART/FP_FPSTAR_PRE_REPO.txt") wt=$(wc -l < "$ART/FP_FPSTAR_PRE_WT.txt"))"

# =============================================================================
PHASE="ENVIRONMENT_FINGERPRINT"
say "=== ENVIRONMENT FINGERPRINT: S4 and the F1 dependency inventory ==="
date -u +%Y-%m-%dT%H:%M:%SZ > "$FP"
"$PY" -VV                       >> "$FP" 2>&1 || stop S4 "cannot execute interpreter $PY"
readlink -f "$PY"               >> "$FP"
sha256sum "$PY"                 >> "$FP"
cat "$REPO/.venv/pyvenv.cfg"    >> "$FP"
uname -a                        >> "$FP"
head -3 /etc/os-release         >> "$FP"
grep -m1 'model name' /proc/cpuinfo >> "$FP"
grep -E 'MemTotal|MemAvailable' /proc/meminfo >> "$FP"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv >> "$FP" 2>&1

pyver="$("$PY" -c 'import sys; print("%d.%d" % (sys.version_info.major, sys.version_info.minor))' 2>/dev/null)"
[ -n "$pyver" ] || stop S4 "could not determine interpreter version"
pymaj="${pyver%%.*}"; pymin="${pyver##*.}"
if [ "$pymaj" -lt "$PY_MIN_MAJOR" ] \
   || { [ "$pymaj" -eq "$PY_MIN_MAJOR" ] && [ "$pymin" -lt "$PY_MIN_MINOR" ]; } \
   || [ "$pymaj" -gt "$PY_MAX_MAJOR" ] \
   || { [ "$pymaj" -eq "$PY_MAX_MAJOR" ] && [ "$pymin" -ge "$PY_MAX_MINOR" ]; }; then
  stop S4 "interpreter $pyver outside authorized range >=${PY_MIN_MAJOR}.${PY_MIN_MINOR},<${PY_MAX_MAJOR}.${PY_MAX_MINOR}"
fi
record S4 PASS "interpreter $pyver satisfies >=3.11,<3.13"

: > "$ART/FP_packages_missing.txt"
for d in "$REPO"/.venv/lib/python3.12/site-packages/*.dist-info; do
  if [ ! -f "$d/METADATA" ]; then
    printf 'MISSING_METADATA %s\n' "$(basename "$d")" >> "$ART/FP_packages_missing.txt"
    continue
  fi
  awk '/^Name: /{if(!n){n=substr($0,7)}}
       /^Version: /{if(!v){v=substr($0,10)}}
       END{printf "%s==%s\n", (n?n:"MISSING_NAME"), (v?v:"MISSING_VERSION")}' "$d/METADATA"
done | sort > "$ART/FP_packages.txt"
pkgs_digest="$(sha256sum "$ART/FP_packages.txt" | cut -d' ' -f1)"
printf '%s  %s\n' "$pkgs_digest" "$ART/FP_packages.txt" >> "$FP"
wc -l < "$ART/FP_packages.txt" > "$ART/FP_packages_count.txt"

if [ -s "$ART/FP_packages_missing.txt" ]; then
  stop S5 "dependency inventory incomplete: $(wc -l < "$ART/FP_packages_missing.txt") dist-info dirs lack METADATA"
fi
record S5_INFO INFO "F1 inventory complete: $(cat "$ART/FP_packages_count.txt") distributions, 0 missing METADATA, digest=$pkgs_digest"

env | cut -d= -f1 | sort > "$ART/FP_env_names.txt"
( cd "$WT" && ls poetry.lock uv.lock Pipfile.lock constraints.txt ) > "$ART/FP_lockfile_state.txt" 2>&1
rc=$?; write_exit_record lockfile_state "$rc" n/a LOCKFILE_PROBE
record LOCKFILE INFO "lockfile probe exit=$rc (non-zero expected when absent; not a blanket pass)"
say "ENVIRONMENT PASS: S4 satisfied; packages=$(cat "$ART/FP_packages_count.txt") pkgs_digest=$pkgs_digest"

# =============================================================================
PHASE="PRE_RUN_MANIFEST"
say "=== PRE-RUN MANIFEST: exact unreadable-set validation ==="
# ENUM (v6): the proposed ENUM condition is NOT authorized and is NOT enforced.
# v5 called `stop ENUM`, which activated an unauthorized stop condition. v6
# routes Git path-enumeration failure through the INTERNAL-error fail-closed path
# (die_internal): non-zero exit, truthful error, records INTERNAL rather than
# claiming an authorized S-condition was violated, and does NOT add an ENUM row
# to the enforcement ledger. This is a precondition failure of the runner, not a
# stop-condition finding. The ENUM proposal remains PROPOSED_NOT_AUTHORIZED
# pending governance approval (see decisions/ENUM_PROPOSAL_20261010.md (in-package, PROPOSED_NOT_AUTHORIZED)).
git -C "$WT" ls-files -z > "$ART/FP_tracked.z"
rc=$?; write_exit_record tracked_lsfiles "$rc" n/a GIT_LS_FILES
[ "$rc" -eq 0 ] || die_internal "git ls-files failed (exit $rc); tracked-file enumeration unavailable, so no manifest can be built. This is a runner precondition failure routed to the internal-error path; it is NOT an authorized ENUM/S6/S17 stop condition."
sha256sum "$ART/FP_tracked.z" > "$ART/FP_tracked_list_digest.txt"

( cd "$WT" && xargs -0 -a "$ART/FP_tracked.z" sha256sum ) > "$ART/FP_BEFORE.sha256" 2> "$ART/FP_BEFORE_unreadable.txt"
rc=$?; write_exit_record BEFORE "$rc" n/a MANIFEST_BEFORE_EXPECTED_NONZERO
wc -l < "$ART/FP_BEFORE.sha256" > "$ART/FP_BEFORE_count.txt"
sha256sum "$ART/FP_BEFORE.sha256" >> "$FP"

normalized_authorized="$(printf '%s\n' $AUTHORIZED_UNREADABLE | sort)"
AUTHORIZED_UNREADABLE_SHA256="$(printf '%s\n' "$normalized_authorized" | sha256sum | cut -d' ' -f1)"
observed_before="$(sed -n 's/^sha256sum: \(.*\): No such file or directory$/\1/p' "$ART/FP_BEFORE_unreadable.txt" | sort)"

if [ "$observed_before" != "$normalized_authorized" ]; then
  printf 'authorized_set:\n%s\n\nobserved_set:\n%s\n' "$normalized_authorized" "$observed_before" > "$ART/FP_UNREADABLE_SET_MISMATCH.txt"
  stop S7 "pre-run unreadable set does not match the authorized set exactly; see FP_UNREADABLE_SET_MISMATCH.txt"
fi
record S7_BEFORE PASS "pre-run unreadable set matches the 4 authorized symlinks exactly (set-sha256=$AUTHORIZED_UNREADABLE_SHA256)"

if [ "$rc" -eq 0 ]; then
  printf 'observed_set:\n%s\n' "$normalized_authorized" > "$ART/FP_MANIFEST_EXIT_ANOMALY.txt"
  stop S7 "manifest command exited 0 yet the authorized broken-symlink set was reported unreadable; evidence is inconsistent"
fi
record MANIFEST_BEFORE INFO "exit=$rc is EXPECTED and explained by exactly the 4 authorized broken symlinks"

# A-10: BEFORE-side symlink blob baseline.
git -C "$WT" ls-files -s > "$ART/FP_symlinks_before.txt"
verify_symlink_blobs() { # index_file label
  local idx="$1" label="$2" pair sym_name sym_blob
  for pair in $AUTHORIZED_SYMLINK_BLOBS; do
    sym_name="${pair%%=*}"; sym_blob="${pair##*=}"
    if ! awk -v n="$sym_name" -v b="$sym_blob" '$4==n && $1=="120000" && $2==b {found=1} END{exit !found}' "$idx"; then
      return 1
    fi
  done
  return 0
}
if verify_symlink_blobs "$ART/FP_symlinks_before.txt" before; then
  record S7_BLOBS_BEFORE PASS "all 4 authorized symlinks present with baseline blob hashes (pre-run)"
else
  stop S7 "an authorized symlink is missing, renamed, or its blob hash differs from the baseline (pre-run)"
fi
git -C "$WT" ls-files -s | grep 120000 > "$ART/FP_symlinks.txt"
record SYMLINKS INFO "$(wc -l < "$ART/FP_symlinks.txt") tracked symlinks recorded"
say "PRE-RUN MANIFEST PASS: hashed=$(cat "$ART/FP_BEFORE_count.txt"); unreadable set verified exactly"

# =============================================================================
PHASE="PREFLIGHT"
say "=== PREFLIGHT GATE for mandatory authorization values ==="
# Every mandatory authorization value must be resolved BEFORE any test is
# collected or executed. A missing value refuses here, records exactly what is
# needed, and states that no floor ran. Nothing is invented or silently waived.
{
  printf 'PREFLIGHT GATE\n'
  printf 'utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'observed_packages_digest=%s\n' "$pkgs_digest"
  printf 'expected_packages_digest=%s\n' "${EXPECT_PACKAGES_DIGEST:-<NOT_PROVIDED>}"
  printf 's10_ceiling_seconds=%s\n' "${S10_CEILING_SECONDS:-<NOT_PROVIDED>}"
  printf 's10_ceiling_source=%s\n' "${DECISIONS_FILE:-<none>}"
  printf 'e2_authorized_minimum_seconds=%s\n' "$E2_MINIMUM_BUDGET_SECONDS"
  printf 'e2_meaning=minimum headroom, NOT a ceiling; unchanged\n'
  printf 'runtime_validation_authorized=%s\n' "${RUNTIME_VALIDATION_AUTHORIZED:-<UNKNOWN>}"
} > "$ART/FP_PREFLIGHT.txt"

if [ -z "$EXPECT_PACKAGES_DIGEST" ] && [ "$ALLOW_UNENFORCED_S5" != "1" ]; then
  preflight_refuse S5 "no operator-pinned expected dependency-inventory digest; the packet fixes the METHOD (F1/METADATA) but not the expected value. Observed digest for the operator to accept or reject: $pkgs_digest"
fi
if [ -n "$EXPECT_PACKAGES_DIGEST" ]; then
  [ "$pkgs_digest" != "$EXPECT_PACKAGES_DIGEST" ] && stop S5 "dependency inventory digest mismatch: got $pkgs_digest want $EXPECT_PACKAGES_DIGEST"
  record S5 PASS "dependency inventory digest == operator-pinned $EXPECT_PACKAGES_DIGEST"
else
  record S5 BLOCKED_WAIVED "no pinned digest; operator waiver ALLOW_UNENFORCED_S5=1 recorded; observed digest $pkgs_digest"
  say "WARN: S5 waived by operator; proceeding under explicit waiver"
fi

if [ -z "$S10_CEILING_SECONDS" ] && [ "$ALLOW_UNENFORCED_S10" != "1" ]; then
  preflight_refuse S10 "no authorized wall-clock CEILING could be loaded from the decision artifact; the E-2 minimum is not a ceiling"
fi
if [ -n "$S10_CEILING_SECONDS" ]; then
  record S10_ARMED INFO "wall-clock ceiling ${S10_CEILING_SECONDS}s armed from the approved decision (separate from the unchanged E-2 minimum ${E2_MINIMUM_BUDGET_SECONDS}s)"
else
  record S10 BLOCKED_WAIVED "no ceiling loaded; operator waiver ALLOW_UNENFORCED_S10=1 recorded"
fi
PHASE_PREFLIGHT_DONE=1
say "PREFLIGHT PASS: authorization resolved; collection may begin"

# =============================================================================
PHASE="COLLECTION"
say "=== COLLECTION (a collection phase, NOT the floor) ==="
# A-7: collection is its own phase. It is neither "pre-execution" nor the floor.
run_phase collect env "PYTHONPATH=src" "$PY" -m pytest tests/ --collect-only -q --no-header
rc_collect=$(exit_field collect exit)
verdict_collect=$(exit_field collect verdict)
route_phase_verdict collect "$rc_collect" "$verdict_collect"
if [ "$rc_collect" -ne 0 ]; then
  PHASE_COLLECTION_DONE=1
  stop S9 "collection exited $rc_collect; a collection error is not a test result"
fi
record S9 PASS "collection exit=0"
PHASE_COLLECTION_DONE=1

# =============================================================================
PHASE="SUITE"
say "=== ROOT SUITE (THE FLOOR) ==="
date -u +%Y-%m-%dT%H:%M:%SZ > "$ART/FP_run_start.txt"
if [ -n "$S10_CEILING_SECONDS" ]; then
  run_phase suite timeout --signal=TERM --kill-after=30 "${S10_CEILING_SECONDS}s" env "PYTHONPATH=src" "$PY" -m pytest tests/ -q --no-header
else
  run_phase suite env "PYTHONPATH=src" "$PY" -m pytest tests/ -q --no-header
fi
date -u +%Y-%m-%dT%H:%M:%SZ > "$ART/FP_run_end.txt"
grep -E 'MemAvailable' /proc/meminfo >> "$ART/FP_run_end.txt"
rc_suite=$(exit_field suite exit)
verdict_suite=$(exit_field suite verdict)
elapsed_suite=$(exit_field suite elapsed_seconds)
PHASE_SUITE_DONE=1

route_phase_verdict suite "$rc_suite" "$verdict_suite"

{
  printf 'elapsed_seconds=%s\n' "$elapsed_suite"
  printf 'e2_authorized_minimum_budget_seconds=%s\n' "$E2_MINIMUM_BUDGET_SECONDS"
  printf 'e2_meaning=minimum headroom for the suite phase; NOT a ceiling\n'
  printf 's10_ceiling_seconds=%s\n' "${S10_CEILING_SECONDS:-UNSET_WAIVED}"
} > "$ART/FP_budget.txt"

# S10 is evaluated from the recorded elapsed time. A timeout already recorded by
# route_phase_verdict must not be double-counted, so only a wall-clock breach
# without a timeout verdict is recorded here.
if [ -n "$S10_CEILING_SECONDS" ] && [ "$verdict_suite" != "TIMEOUT" ]; then
  if [ "$elapsed_suite" -gt "$S10_CEILING_SECONDS" ]; then
    violate S10 "suite elapsed ${elapsed_suite}s exceeded authorized ceiling ${S10_CEILING_SECONDS}s"
  else
    record S10 PASS "suite elapsed ${elapsed_suite}s within authorized ceiling ${S10_CEILING_SECONDS}s"
  fi
elif [ -z "$S10_CEILING_SECONDS" ]; then
  record S10_OBSERVED INFO "suite elapsed ${elapsed_suite}s recorded; no ceiling authorized, so S10 could not be evaluated (waived)"
fi

if [ "$rc_suite" -ne 0 ]; then
  violate SUITE_EXIT "root suite exited $rc_suite"
else
  record SUITE_EXIT PASS "root suite exit=0, elapsed=${elapsed_suite}s"
fi

# =============================================================================
PHASE="GUARDRAIL"
say "=== GUARDRAIL SUB-RUN (separate, overlapping, NEVER summed) ==="
run_phase guard env "PYTHONPATH=src" "$PY" -m pytest tests/test_p2_guardrail_*.py -q --no-header
rc_guard=$(exit_field guard exit)
verdict_guard=$(exit_field guard verdict)

route_phase_verdict guard "$rc_guard" "$verdict_guard"
if [ "$rc_guard" -ne 0 ]; then
  violate GUARD_EXIT "guardrail run exited $rc_guard"
else
  record GUARD_EXIT PASS "guardrail exit=0 (reported separately; NOT summed with root total)"
fi
{
  printf 'root_suite_total=see FP_suite.out final summary line\n'
  printf 'guardrail_total=see FP_guard.out final summary line\n'
  printf 'summation_rule=NEVER sum; guardrail targets are an overlapping subset of tests/\n'
  printf 'guardrail_target_glob=tests/test_p2_guardrail_*.py\n'
  printf 'root_target=tests/\n'
} > "$ART/FP_SEPARATION_NOTICE.txt"
say "GUARDRAIL done: exit=$rc_guard (separate, not summed)"

# =============================================================================
PHASE="POST_RUN_INTEGRITY"
say "=== POST-RUN INTEGRITY: manifests, scope, and independent checks ==="
git -C "$WT" rev-parse HEAD 'HEAD^{tree}' > "$ART/FP_post_identity.txt" 2>&1
git -C "$WT" status --porcelain            > "$ART/FP_post_status.txt" 2>&1
git -C "$WT" worktree list                 > "$ART/FP_worktrees_post.txt" 2>&1

( cd "$WT" && xargs -0 -a "$ART/FP_tracked.z" sha256sum ) > "$ART/FP_AFTER.sha256" 2> "$ART/FP_AFTER_unreadable.txt"
rc=$?; write_exit_record AFTER "$rc" n/a MANIFEST_AFTER_EXPECTED_NONZERO
wc -l < "$ART/FP_AFTER.sha256" > "$ART/FP_AFTER_count.txt"
sha256sum "$ART/FP_AFTER.sha256" > "$ART/FP_AFTER_manifest_digest.txt"

# S7 after-side: exact set, then set equality, then (A-10) blob re-verification.
observed_after="$(sed -n 's/^sha256sum: \(.*\): No such file or directory$/\1/p' "$ART/FP_AFTER_unreadable.txt" | sort)"
if [ "$observed_after" != "$normalized_authorized" ]; then
  printf 'authorized_set:\n%s\n\nobserved_set:\n%s\n' "$normalized_authorized" "$observed_after" > "$ART/FP_UNREADABLE_SET_MISMATCH_AFTER.txt"
  violate S7 "post-run unreadable set does not match the authorized set exactly"
else
  record S7_AFTER PASS "post-run unreadable set matches the 4 authorized symlinks exactly"
fi

diff "$ART/FP_BEFORE_unreadable.txt" "$ART/FP_AFTER_unreadable.txt" > "$ART/FP_unreadable_diff.txt" 2>&1
rc=$?; write_exit_record unreadable_diff "$rc" n/a DIFF_UNREADABLE_SETS
if [ "$rc" -ne 0 ] || [ -s "$ART/FP_unreadable_diff.txt" ]; then
  violate S7 "unreadable-file set changed between before and after"
else
  record S7_DIFF PASS "unreadable set byte-identical before and after"
fi

# A-10: after-side symlink blob verification.
git -C "$WT" ls-files -s > "$ART/FP_symlinks_after.txt"
if verify_symlink_blobs "$ART/FP_symlinks_after.txt" after; then
  record S7_BLOBS_AFTER PASS "all 4 authorized symlinks still present with baseline blob hashes (post-run)"
else
  violate S7 "an authorized symlink changed identity during the run (missing, renamed, or different blob hash)"
fi

nb=$(cat "$ART/FP_BEFORE_count.txt"); na=$(cat "$ART/FP_AFTER_count.txt")

# ---------------------------------------------------------------------------
# A-3 / A-1: scope mismatch handling.
#
# S6 (UNCHANGED): BEFORE/AFTER line counts differ -> SCOPE_MISMATCH is written.
# v3 called `finalize SUCCESS` here, which skipped S8 verify, S13 and S16.
# v4 records the violation and CONTINUES. Only the hash diff is skipped, because
# it genuinely depends on both manifests describing the same scope. Worktree
# cleanliness (S13), artifact isolation (S16) and manifest re-verification are
# INDEPENDENT of scope and therefore still run.
# ---------------------------------------------------------------------------
SCOPE_OK=1
if [ "$nb" -ne "$na" ]; then
  SCOPE_OK=0
  {
    printf 'SCOPE_MISMATCH before=%s after=%s\n' "$nb" "$na"
    printf 'scope_before=%s\nscope_after=%s\ndiff_exit=NOT_RUN\ndiff_lines=NOT_RUN\n' "$nb" "$na"
    printf 'diff_skipped_reason=manifests describe different scopes; comparing hashes is undefined\n'
  } > "$ART/FP_diff_summary.txt"
  printf 'S6_SCOPE_MISMATCH before=%s after=%s\n' "$nb" "$na" > "$ART/FP_SCOPE_MISMATCH.txt"
  violate S6 "manifest scopes differ (before=$nb after=$na); hash diff skipped, independent checks continue"
fi

# ---------------------------------------------------------------------------
# A-1: S17, the AUTHORIZED literal condition.
#
# Authorized: "FP_diff_summary.txt reports SCOPE_MISMATCH" (manifests built from
# different file sets). In v3 the equivalent check was unreachable because S6
# short-circuited first.
#
# v4 makes it reachable in BOTH branches, and does not weaken S6:
#   * SCOPE_OK=0 : S6 already wrote the marker; S17 ASSERTS THE MARKER IS
#                  PRESENT. The authorized condition is satisfied, so S17 PASSES
#                  and S6 alone carries the failure.
#   * SCOPE_OK=1 : the summary was written without a marker; S17 ASSERTS THE
#                  MARKER IS ABSENT. If it is present, S17 FAILS.
#
# The marker therefore cannot be lost between S6 and S17, and its absence is
# verified. A v3-style "unreachable grep" is not used.
# ---------------------------------------------------------------------------
if [ "$SCOPE_OK" -eq 0 ]; then
  if grep -q 'SCOPE_MISMATCH' "$ART/FP_diff_summary.txt"; then
    record S17 PASS "FP_diff_summary.txt reports SCOPE_MISMATCH as required for a scope mismatch (marker present, paired with S6)"
  else
    # Unreachable unless the summary was corrupted between S6 and S17.
    violate S17 "scope mismatch recorded by S6 but FP_diff_summary.txt does not report SCOPE_MISMATCH; evidence is inconsistent"
  fi
else
  if grep -q 'SCOPE_MISMATCH' "$ART/FP_diff_summary.txt"; then
    violate S17 "FP_diff_summary.txt reports SCOPE_MISMATCH although manifest line counts are equal (before=$nb after=$na); manifests built from different file sets"
  else
    record S17 PASS "FP_diff_summary.txt does not report SCOPE_MISMATCH and manifest scopes are equal ($nb)"
  fi
fi

if [ "$SCOPE_OK" -eq 1 ]; then
  record S6 PASS "manifest scope equal before and after ($nb entries)"

  diff <(sort "$ART/FP_BEFORE.sha256") <(sort "$ART/FP_AFTER.sha256") > "$ART/FP_HASH_DIFF.txt"
  diff_rc=$?
  diff_lines=$(wc -l < "$ART/FP_HASH_DIFF.txt")
  {
    printf 'scope_before=%s\n' "$nb"
    printf 'scope_after=%s\n'  "$na"
    printf 'diff_exit=%s\n'    "$diff_rc"
    printf 'diff_lines=%s\n'   "$diff_lines"
  } > "$ART/FP_diff_summary.txt"

  # Additional diagnostic (NOT the S17 trigger): equal counts with differing
  # paths would mean the manifests describe different file sets.
  sed -E 's/^[0-9a-f]{64}[[:space:]]+//' "$ART/FP_BEFORE.sha256" | sort > "$ART/FP_BEFORE_PATHS.txt"
  sed -E 's/^[0-9a-f]{64}[[:space:]]+//' "$ART/FP_AFTER.sha256"  | sort > "$ART/FP_AFTER_PATHS.txt"
  comm -3 "$ART/FP_BEFORE_PATHS.txt" "$ART/FP_AFTER_PATHS.txt" > "$ART/FP_PATH_SET_DIFF.txt"
  n_path_diff=$(wc -l < "$ART/FP_PATH_SET_DIFF.txt")
  if [ "$n_path_diff" -ne 0 ]; then
    violate S17_PATHCHECK "manifest path sets differ in $n_path_diff entries despite equal counts; diagnostic finding (S17 marker itself was absent)"
  else
    record S17_PATHCHECK PASS "manifest path sets identical ($nb paths)"
  fi

  if [ "$diff_rc" -ne 0 ] || [ "$diff_lines" -ne 0 ]; then
    violate S8 "protected evidence modified: ${diff_lines} diff line(s), diff exit $diff_rc"
  else
    record S8 PASS "no ADDED/REMOVED/CHANGED entries; ${nb} tracked files byte-identical"
  fi
else
  record S8 SKIPPED "hash diff skipped because manifest scope is invalid; this is the only scope-dependent check"
fi

# --- manifest re-verification (independent of scope) ----------------------
( cd "$WT" && sha256sum -c "$ART/FP_BEFORE.sha256" ) > "$ART/FP_verify_BEFORE.out" 2> "$ART/FP_verify_BEFORE.err"
rc=$?; write_exit_record verify_BEFORE "$rc" n/a VERIFY_MANIFEST
grep -v ': OK$' "$ART/FP_verify_BEFORE.out" > "$ART/FP_verify_BEFORE_failures.txt" 2>/dev/null || true
sha256sum "$ART/FP_BEFORE.sha256" > "$ART/FP_verify_manifest_digest.txt"
git -C "$WT" rev-parse 'HEAD^{tree}' > "$ART/FP_verify_tree.txt" 2>&1

# A-4: emitted header states the TRUE count (16) and the runner self-checks it.
ALL_EXIT_LINES=0
{
  printf '# FP_all_exit_codes.txt\n'
  printf '# concatenation of FP_suite.exit, FP_collect.exit, FP_guard.exit\n'
  printf '# each contributes exactly 3 lines (exit=, elapsed_seconds=, verdict=)\n'
  printf '# structure: 4 header lines + 3 x (1 format marker + 3 record lines) = 16\n'
  printf '# format=FP_suite.exit\n'
  cat "$ART/FP_suite.exit"
  printf '# format=FP_collect.exit\n'
  cat "$ART/FP_collect.exit"
  printf '# format=FP_guard.exit\n'
  cat "$ART/FP_guard.exit"
} > "$ART/FP_all_exit_codes.txt"
ALL_EXIT_LINES=$(wc -l < "$ART/FP_all_exit_codes.txt")
if [ "$ALL_EXIT_LINES" -eq 16 ]; then
  record EXIT_AGGREGATE_FORMAT PASS "FP_all_exit_codes.txt emitted with the documented 16 lines"
else
  record EXIT_AGGREGATE_FORMAT INFO "FP_all_exit_codes.txt emitted $ALL_EXIT_LINES lines; documented value is 16 - format drift"
fi

if [ -s "$ART/FP_verify_BEFORE_failures.txt" ]; then
  violate S8 "manifest re-verification reported $(wc -l < "$ART/FP_verify_BEFORE_failures.txt") failing file(s)"
else
  record VERIFY PASS "sha256sum -c reported zero failures"
fi

# --- S13: worktree clean at run end (independent of manifest scope) ---------
if [ -s "$ART/FP_post_status.txt" ]; then
  violate S13 "worktree mutated by the run: $(head -5 "$ART/FP_post_status.txt" | tr '\n' ';')"
else
  record S13 PASS "git status --porcelain empty at run end"
fi

# --- S16: post-run scan, same rule and same baselines as the worktree ------
scan_fpstar "$REPO" "$ART/FP_FPSTAR_POST_REPO.txt"
scan_fpstar "$WT"  "$ART/FP_FPSTAR_POST_WT.txt"
: > "$ART/FP_FPSTAR_NEW.txt"
comm -13 "$ART/FP_FPSTAR_PRE_REPO.txt" "$ART/FP_FPSTAR_POST_REPO.txt" >> "$ART/FP_FPSTAR_NEW.txt"
comm -13 "$ART/FP_FPSTAR_PRE_WT.txt"   "$ART/FP_FPSTAR_POST_WT.txt"   >> "$ART/FP_FPSTAR_NEW.txt"
if [ -s "$ART/FP_FPSTAR_NEW.txt" ]; then
  violate S16 "run contaminated its own measurement target: $(head -5 "$ART/FP_FPSTAR_NEW.txt" | tr '\n' ';')"
else
  record S16 PASS "no new FP_* artifact inside REPO or WT (.git-only exclusion applied to both roots; baselines taken after worktree creation)"
fi

# =============================================================================
PHASE="FINALIZATION"
say "=== FINALIZATION: exit status is DERIVED from the ledger ==="
say "runner verdict describes RUN VALIDITY only; it is NOT gate acceptance"
say "Worktree intentionally LEFT IN PLACE for independent review; removal is post-review."
finalize SUCCESS "reached_end_of_run"