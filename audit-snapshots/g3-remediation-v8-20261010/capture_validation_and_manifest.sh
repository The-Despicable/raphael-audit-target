#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 — v8 package capture + integrity generation.
# Does NOT execute the v8 runner, the floor suite, or application code.
#
# DETERMINISTIC ORDER (carried forward from v7):
#   1. syntax checks + isolated tests
#   2. write final NOT_VALIDATED.txt
#   3. temps live in mktemp -d OUTSIDE the package
#   4. final on-disk inventory
#   5. write manifest_inventory_check.txt to FINAL content
#   6. generate the checksum manifest LAST (self-excluded)
#   7. ACTUALLY run sha256sum -c and record real matched/mismatched totals
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAL="$ROOT/validation"
RUNNER="$ROOT/g3-floor-run-v8-integrity.sh"
MANIFEST="HANDOFF_MANIFEST_V8_20261010.md"
RECON="$VAL/manifest_inventory_check.txt"
mkdir -p "$VAL"

bash -n "$RUNNER" > "$VAL/bash_n_stdout.txt" 2> "$VAL/bash_n_stderr.txt"; rc=$?
printf 'command=bash -n g3-floor-run-v8-integrity.sh\nexit=%s\n' "$rc" > "$VAL/bash_n_result.txt"
echo "runner bash -n exit=$rc"
bash -n "$ROOT/g3_v8_lib.sh" > "$VAL/lib_n_stdout.txt" 2> "$VAL/lib_n_stderr.txt"; lrc=$?
printf 'command=bash -n g3_v8_lib.sh\nexit=%s\n' "$lrc" > "$VAL/lib_n_result.txt"
echo "lib    bash -n exit=$lrc"

bash "$VAL/test_v8_regressions.sh" > "$VAL/test_v8_regressions.out" 2>&1; trc=$?
tail -2 "$VAL/test_v8_regressions.out" | sed 's/^/  regressions: /'
bash "$VAL/test_v8_decisions.sh"    > "$VAL/test_v8_decisions.out" 2>&1; drc=$?
tail -2 "$VAL/test_v8_decisions.out" | sed 's/^/  decisions:   /'

cat > "$VAL/NOT_VALIDATED.txt" <<'EOF'
NOT VALIDATED (runtime) — no floor run is authorized; the v8 runner has NEVER been executed.
Shell syntax checking, isolated unit tests and checksum verification are NOT runtime validation.
No G3 runner execution, floor suite, Raphael application code, benchmark or red-team operation
was performed at any point in producing this candidate.

  - S14 artifact-isolation boundary: code + isolated containment tests only.
      Evidence would be a real run: ART/WT creation refused inside a protected location.
  - S7  hash-error accounting: isolated fixture tests only.
      Evidence would be a real run: FP_UNHASHED_BEFORE/AFTER.txt and FP_UNREADABLE_SET_MISMATCH*.
  - S16 INCLUDE_VENV scan selection: exercised end-to-end through the real validator + g3_norm_bool.
      Evidence would be a real run: FP_FPSTAR_PRE/POST_*.txt showing the scan executed.
  - S10 2700 s ceiling: armed only if a ceiling is loaded; never executed.
  - S5 dependency digest: BLOCKED pending operator approval; NOT pinned.
  - ENUM enumeration failure: routed to die_internal; NOT an authorized condition; never executed.
  - S6/S8/S13/S17 and all other stop conditions: NOT runtime-verified.

Verified here: bash -n (parse), isolated unit tests against the shared production library,
and SHA256 manifest verification. None of these prove runner behavior.
EOF

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cd "$ROOT" || exit 1
find . -type f -printf '%P\n' | sort > "$TMPD/disk"
disk_total=$(wc -l < "$TMPD/disk")

{
  echo "MANIFEST INVENTORY RECONCILIATION (v8)"
  echo ""
  echo "GENERATION ORDER: validation -> final inventory -> this file (final) ->"
  echo "                   checksum manifest (last) -> sha256sum -c verification."
  echo ""
  echo "COUNTS (computed from the actual directory at generation time):"
  echo "  total_files_on_disk_now=$disk_total"
  echo "  manifest_entries_expected=$((disk_total + 1))"
  echo "    (= files_now + this reconciliation file; the manifest is created after"
  echo "     and is self-excluded from its own hash list.)"
  echo ""
  echo "DOCUMENTED CONTROL-FILE EXCLUSIONS:"
  echo "  $MANIFEST"
  echo "    reason: a checksum manifest cannot contain its own digest (self-reference)."
  echo "    treatment: excluded from its own hash list; documented, not a missing file."
  echo "  validation/manifest_verify.out, validation/manifest_verify_summary.txt"
  echo "    reason: produced by the sha256sum -c run that verifies this manifest."
  echo "    treatment: excluded by name (documented in the manifest header); their content"
  echo "               cannot be hashed before the verification they describe."
  echo ""
  echo "TEMPORARY FILES: none inside the package; working files live in mktemp -d OUTSIDE."
  echo ""
  echo "FILES ON DISK (final):"
  cat "$TMPD/disk"
} > "$RECON"

{
  echo "# Integrity manifest — real SHA-256 for every artifact in the v8 package."
  echo "# runner_version=v8-integrity"
  echo "# verification: cd audit-snapshots/g3-remediation-v8-20261010 && sha256sum -c <(grep -v '^#' $MANIFEST)"
  echo "# The manifest is EXCLUDED from its own hash list (self-reference)."
  echo "# The reconciliation file IS covered and was finalized before this manifest."
  echo "#"
  echo "# EXCLUDED BY NAME (documented control outputs, produced AFTER hashing):"
  echo "#   validation/manifest_verify.out        (raw sha256sum -c transcript)"
  echo "#   validation/manifest_verify_summary.txt (human summary of that transcript)"
  echo "#   Reason: both are DERIVED FROM this manifest's verification run, so their"
  echo "#   content cannot be hashed before the verification it describes. They are"
  echo "#   verification evidence, not package content."
  echo "#"
  find . -type f ! -name "$MANIFEST" \
            ! -name 'manifest_verify.out' \
            ! -name 'manifest_verify_summary.txt' \
       -printf '%P\n' | sort | while read -r f; do sha256sum "$f"; done
} > "$MANIFEST"
echo "manifest entries: $(grep -vc '^#' "$MANIFEST")"

grep -v '^#' "$MANIFEST" > "$TMPD/checks"
sha256sum -c "$TMPD/checks" > "$VAL/manifest_verify.out" 2>&1; vrc=$?
matched=$(grep -c ': OK$' "$VAL/manifest_verify.out" || true)
mismatched=$(grep -c 'FAILED' "$VAL/manifest_verify.out" || true)
listed=$(wc -l < "$TMPD/checks")
{
  echo "MANIFEST VERIFICATION (integrity proven by actual verification)"
  echo "command: cd audit-snapshots/g3-remediation-v8-20261010 && sha256sum -c <(grep -v '^#' $MANIFEST)"
  echo "sha256sum_c_exit=$vrc"
  echo "entries_listed=$listed"
  echo "entries_matched_OK=$matched"
  echo "entries_mismatched_FAILED=$mismatched"
  echo ""
  echo "Full output:"
  cat "$VAL/manifest_verify.out"
} > "$VAL/manifest_verify_summary.txt"
echo "VERIFY: listed=$listed matched=$matched mismatched=$mismatched rc=$vrc"
echo "tests: regressions_exit=$trc decisions_exit=$drc"
echo "done"