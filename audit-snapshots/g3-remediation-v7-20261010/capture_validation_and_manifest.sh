#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 — v7 package capture + integrity generation (E-5 / E-8 fixed)
# =============================================================================
# Does NOT execute the v7 runner, the floor suite, or application code.
#
# DETERMINISTIC GENERATION ORDER (the E-5 / E-8 fix):
#
#   Step 1  Static validation of the runner (bash -n) + isolated unit tests.
#   Step 2  Write the final NOT_VALIDATED.txt (no temp files inside the package).
#   Step 3  Create ALL temporary working files in a mktemp -d directory OUTSIDE
#           the package (so no .disk.tmp / .mani.tmp ever appears inside it).
#   Step 4  Take the FINAL on-disk inventory (temps excluded because they are
#           outside the package). Compute counts from the real directory.
#   Step 5  Write manifest_inventory_check.txt to its FINAL content. It is NOT
#           rewritten after this point, so its digest in the manifest is valid.
#   Step 6  Generate the checksum manifest LAST, covering every file EXCEPT the
#           manifest itself (self-reference limitation, documented).
#   Step 7  ACTUALLY RUN `sha256sum -c` over the completed manifest and record the
#           real matching/mismatching totals. Integrity is never claimed merely
#           because generation completed.
#
# A second invocation re-runs from step 1 and is byte-reproducible because every
# artifact is finalized before it is hashed.
# =============================================================================
set -uo pipefail
ROOT=/home/yaser/audit-rsi1/g3-remediation-v7-20261010
VAL="$ROOT/validation"
RUNNER="$ROOT/g3-floor-run-v7-integrity.sh"
MANIFEST="HANDOFF_MANIFEST_V7_20261010.md"
RECON="$VAL/manifest_inventory_check.txt"
mkdir -p "$VAL"

# --- Step 1a: shell syntax validation (parse only) --------------------------
bash -n "$RUNNER" > "$VAL/bash_n_stdout.txt" 2> "$VAL/bash_n_stderr.txt"
rc=$?
printf 'command=bash -n g3-floor-run-v7-integrity.sh\nexit=%s\n' "$rc" > "$VAL/bash_n_result.txt"
echo "bash -n exit=$rc"

# --- Step 1b: shellcheck availability (informational) ------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$RUNNER" > "$VAL/shellcheck_stdout.txt" 2> "$VAL/shellcheck_stderr.txt"
  printf 'shellcheck_exit=%s\n' "$?" > "$VAL/shellcheck_result.txt"
else
  printf 'shellcheck=NOT_INSTALLED\nnote=static lint NOT performed; installing tools is not authorized\n' > "$VAL/shellcheck_result.txt"
fi

# --- Step 1c: isolated unit tests (real shared implementation) ---------------
bash "$VAL/test_v7_decisions.sh" > "$VAL/test_v7_decisions.out" 2>&1
test_rc=$?
tail -n 2 "$VAL/test_v7_decisions.out" | sed 's/^/isolated: /'
echo "isolated tests exit=$test_rc"

# --- Step 2: write the final NOT_VALIDATED.txt ------------------------------
cat > "$VAL/NOT_VALIDATED.txt" <<'EOF'
NOT VALIDATED (runtime) — no floor run is authorized; the v7 runner has NEVER been executed.
Shell syntax checking, isolated unit tests and checksum verification are NOT runtime validation.

  - S1  HEAD identity ............ evidence: FP_phase1_head.txt
  - S2  tree identity ............ evidence: FP_phase1_tree.txt
  - S3  clean worktree at start .. evidence: FP_phase1_status.txt
  - S4  interpreter range ........ evidence: FP_start.txt
  - S5  dependency digest ........ BLOCKED pending operator approval (observed a23b7156..., not pinned)
  - S6  manifest line-count scope  evidence: FP_BEFORE_count.txt, FP_AFTER_count.txt, FP_diff_summary.txt
  - S7  unreadable-file set ...... evidence: FP_BEFORE_unreadable.txt, FP_AFTER_unreadable.txt,
                                          FP_symlinks_before.txt, FP_symlinks_after.txt
  - S8  protected content unchanged evidence: FP_HASH_DIFF.txt, FP_verify_BEFORE_failures.txt
  - S9  collection exit .......... evidence: FP_collect.exit
  - S10 wall-clock ceiling ....... approved 2700 s from decision artifact (execution NOT authorized)
  - S11 OOM / signal termination .. evidence: FP_*.exit verdict= field
  - S12 environmental cause ....... evidence: FP_*.out, FP_*.err (PATTERN-BASED residual)
  - S13 clean worktree at end .... evidence: FP_post_status.txt
  - S14 artifact boundary ........ normalized both-direction containment check (not runtime-proven)
  - S15 ART emptiness ............ independent non-empty guard (not runtime-proven)
  - S16 artifact contamination ... evidence: FP_FPSTAR_PRE/POST_*.txt (INCLUDE_VENV per decision)
  - S17 SCOPE_MISMATCH invariant .. evidence: FP_diff_summary.txt (literal marker retained)
  - DECISION config load/validate evidence: FP_PREFLIGHT.txt (not runtime-proven)
  - ENUM enumeration failure ..... PROPOSED_NOT_AUTHORIZED; routed to die_internal (INTERNAL, exit 3)

Also unvalidated at runtime: the whole v7 runner; fail-closed escalation; the S10 env-conflict
guard inside the runner; the decision-consumption path inside the runner.
Only bash -n (parse), isolated tests, and checksum verification were performed.
EOF

# --- Step 3: temp workspace OUTSIDE the package ------------------------------
TMPD="$(mktemp -d)"
cleanup(){ rm -rf "$TMPD"; }
trap cleanup EXIT

# --- Step 4: FINAL on-disk inventory (no temp files inside the package) ------
cd "$ROOT" || exit 1
find . -type f -printf '%P\n' | sort > "$TMPD/disk.list"
disk_total=$(wc -l < "$TMPD/disk.list")

# Files that will exist in the final package but are control files, each with a
# documented reason. The manifest is self-excluded (cannot hash itself); this
# reconciliation file is hashed (it is finalized before the manifest is built).
control_files=1   # the checksum manifest itself

# expected manifest entries = every file that exists now, plus this
# reconciliation file (written next), minus the manifest (excluded).
# Nothing is hardcoded: computed from the real directory listing.
files_now=$(wc -l < "$TMPD/disk.list")

# --- Step 5: write the reconciliation file to its FINAL content --------------
# It is written exactly once and never rewritten, so the manifest digest of it
# is computed from its final bytes.
{
  echo "MANIFEST INVENTORY RECONCILIATION (E-5 / E-8 fixed)"
  echo "generated_by=capture_validation_and_manifest.sh (v7)"
  echo ""
  echo "GENERATION ORDER: validation -> final inventory -> this file (final) ->"
  echo "                   checksum manifest (last) -> sha256sum -c verification."
  echo ""
  echo "COUNTS (computed from the actual directory at generation time):"
  echo "  total_files_on_disk_now=$disk_total"
  echo "  manifest_entries_expected=$((files_now + 1))"
  echo "  (manifest_entries_expected = files_now + this reconciliation file;"
  echo "   the checksum manifest is created afterwards and is self-excluded.)"
  echo ""
  echo "DOCUMENTED CONTROL-FILE EXCLUSIONS:"
  echo "  $MANIFEST"
  echo "    reason: the checksum manifest cannot contain its own digest (self-reference)."
  echo "    treatment: excluded from its own hash list; hashed by no one; NOT an"
  echo "               unexplained missing file."
  echo ""
  echo "TEMPORARY FILES: none are created inside this package. All working files"
  echo "  live in a mktemp -d directory OUTSIDE the package and are removed on exit,"
  echo "  so no .disk.tmp / .mani.tmp can appear in the inventory."
  echo ""
  echo "FILES ON DISK (final, relative paths):"
  cat "$TMPD/disk.list"
} > "$RECON"
echo "reconciliation written ($RECON)"

# --- Step 6: generate the checksum manifest LAST -----------------------------
# Covers every file present now EXCEPT the manifest itself. This includes the
# reconciliation file, which is already final.
{
  echo "# Integrity manifest — real SHA-256 for every artifact in this package."
  echo "# runner_version=v7-integrity"
  echo "# verification: cd $ROOT && sha256sum -c <(grep -v '^#' $MANIFEST)"
  echo "# NOTE: this manifest is EXCLUDED from its own hash list (self-reference)."
  echo "#       The reconciliation file (validation/manifest_inventory_check.txt) IS"
  echo "#       covered, and was finalized before this manifest was generated."
  echo "#"
  find . -type f ! -name "$MANIFEST" -printf '%P\n' | sort | while read -r f; do
    sha256sum "$f"
  done
} > "$MANIFEST"
echo "manifest generated (entries: $(grep -vc '^#' "$MANIFEST"))"

# --- Step 7: ACTUALLY VERIFY, and record the real result ---------------------
cd "$ROOT" || exit 1
grep -v '^#' "$MANIFEST" > "$TMPD/checks.txt"
sha256sum -c "$TMPD/checks.txt" > "$VAL/manifest_verify.out" 2>&1
verify_rc=$?
matched=$(grep -c ': OK$' "$VAL/manifest_verify.out" || true)
mismatched=$(grep -c 'FAILED' "$VAL/manifest_verify.out" || true)
listed=$(wc -l < "$TMPD/checks.txt")

{
  echo "MANIFEST VERIFICATION (E-5: integrity proven by actual verification)"
  echo "command: cd $ROOT && sha256sum -c <(grep -v '^#' $MANIFEST)"
  echo "sha256sum_c_exit=$verify_rc"
  echo "entries_listed=$listed"
  echo "entries_matched_OK=$matched"
  echo "entries_mismatched_FAILED=$mismatched"
  echo ""
  echo "Full verification output (every manifest-listed file):"
  cat "$VAL/manifest_verify.out"
  echo ""
  echo "INTEGRITY CLAIM: $mismatched mismatched file(s). Integrity is asserted ONLY"
  echo "  because this actual sha256sum -c run reported it, not because generation"
  echo "  completed. The v6 package FAILED this check for"
  echo "  validation/manifest_inventory_check.txt (hashed then rewritten)."
} > "$VAL/manifest_verify_summary.txt"

echo "VERIFY: listed=$listed matched=$matched mismatched=$mismatched rc=$verify_rc"

# --- cleanup temps (outside package, but be explicit) ------------------------
cleanup
trap - EXIT
echo "done"