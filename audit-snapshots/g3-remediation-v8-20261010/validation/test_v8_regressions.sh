#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 v8 — regression tests for QW-01, QW-02, QW-04 (+ QW-03 contract,
# QW-06 coverage of the prior controls).
#
# These tests source the REAL production library g3_v8_lib.sh — the same file the
# v8 runner sources — so they exercise production behaviour, not a re-created
# approximation. They also run the REAL decision validator and feed its output
# through the REAL boolean-normalization boundary.
#
# They do NOT execute the G3 runner, the floor suite, Raphael application code,
# or any benchmark. All fixtures are created in a temporary directory removed on
# exit. No authoring-machine path is hard-coded.
# =============================================================================
set -uo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$PKG/g3_v8_lib.sh"
VALIDATOR="$PKG/decisions/validate_decisions.py"
DECISIONS="$PKG/decisions/G3_OPERATOR_DECISIONS_V8.json"
PY="${G3_TEST_PYTHON:-python3}"

[ -f "$LIB" ] || { echo "FATAL: library not found: $LIB"; exit 2; }
# shellcheck source=../g3_v8_lib.sh
. "$LIB"

PASS=0; FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok(){ PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

# =============================================================================
# QW-01 : S14 canonicalization + containment (real g3_norm_path /
#         g3_s14_boundary_violation)
# =============================================================================
echo "== QW-01 S14 canonicalization =="

# Canonicalization must resolve every equivalent spelling to the SAME path.
canon(){ g3_norm_path "$1"; }

r="$(canon "$TMP/a/./b")";        [ "$r" = "$TMP/a/b" ] && ok "QW-01 /a/./b canonicalizes" || no "QW-01 /a/./b -> $r"
r="$(canon "$TMP/a/../b")";       [ "$r" = "$TMP/b" ] && ok "QW-01 /a/../b canonicalizes" || no "QW-01 /a/../b -> $r"
r="$(canon "$TMP/x//y/")";        [ "$r" = "$TMP/x/y" ] && ok "QW-01 /x//y/ canonicalizes" || no "QW-01 /x//y/ -> $r"
r="$(canon "$TMP/plain///")";     [ "$r" = "$TMP/plain" ] && ok "QW-01 trailing separators canonicalize" || no "QW-01 trailing -> $r"
r="$(canon "$TMP")";              [ "$r" = "$TMP" ] && ok "QW-01 plain path unchanged" || no "QW-01 plain -> $r"

# Relative input must become absolute (canonical).
r="$(cd "$TMP" && canon "./sub")"; [ "$r" = "$TMP/sub" ] && ok "QW-01 relative input becomes absolute" || no "QW-01 relative -> $r"

# Nonexistent destination must canonicalize (no existence assumption).
r="$(canon "$TMP/does/not/exist/yet")"; [ "$r" = "$TMP/does/not/exist/yet" ] && ok "QW-01 nonexistent destination canonicalizes" || no "QW-01 nonexistent -> $r"

# A symlink pointing outside must resolve to its target.
mkdir -p "$TMP/real_target"
ln -sfn "$TMP/real_target" "$TMP/link_to_target"
r="$(canon "$TMP/link_to_target")"; [ "$r" = "$TMP/real_target" ] && ok "QW-01 symlink resolves to target" || no "QW-01 symlink -> $r"

# Canonicalization must fail closed on an empty input.
if canon "" >/dev/null 2>&1; then no "QW-01 empty input must fail closed"; else ok "QW-01 empty input fails closed"; fi

echo
echo "== QW-01 containment (both directions) =="

mkdir -p "$TMP/protected/inner" "$TMP/sibling"
# 1. ART equal to protected -> violation
if g3_s14_boundary_violation "$TMP/protected" "$TMP/protected" >/dev/null; then
  ok "QW-01 equal ART==protected is a violation"
else no "QW-01 equal ART==protected missed"; fi
# 2. ART descendant of protected -> violation
if g3_s14_boundary_violation "$TMP/protected/inner" "$TMP/protected" >/dev/null; then
  ok "QW-01 descendant ART is a violation"
else no "QW-01 descendant ART missed"; fi
# 3. protected inside ART -> violation (second direction)
if g3_s14_boundary_violation "$TMP/protected" "$TMP/protected/inner" >/dev/null; then
  ok "QW-01 ancestor ART (protected inside ART) is a violation"
else no "QW-01 second direction missed"; fi
# 4. sibling (outside) -> safe
if g3_s14_boundary_violation "$TMP/sibling" "$TMP/protected" >/dev/null; then
  no "QW-01 sibling must be safe"
else ok "QW-01 sibling is safe"; fi
# 5. THE REGRESSION: traversal that escapes a naive lexical prefix test.
#    <protected>/../<protected>/evil resolves INSIDE protected and must be caught.
if g3_s14_boundary_violation "$TMP/protected/../protected/evil" "$TMP/protected" >/dev/null; then
  ok "QW-01 '..' traversal into protected is caught (v7 bypass regression)"
else no "QW-01 '..' traversal BYPASS"; fi

# =============================================================================
# QW-04 : decision boolean normalization (real g3_norm_bool) + real validator
# =============================================================================
echo
echo "== QW-04 S16 boolean normalization =="

r="$(g3_norm_bool 'True')";  [ "$r" = "true" ]  && ok "QW-04 'True' -> true"  || no "QW-04 'True' -> $r"
r="$(g3_norm_bool 'true')";  [ "$r" = "true" ]  && ok "QW-04 'true' -> true"  || no "QW-04 'true' -> $r"
r="$(g3_norm_bool 'False')"; [ "$r" = "false" ] && ok "QW-04 'False' -> false" || no "QW-04 'False' -> $r"
if g3_norm_bool 'maybe' >/dev/null 2>&1; then no "QW-04 ambiguous value must fail closed"; else ok "QW-04 ambiguous value fails closed"; fi

# End-to-end: run the REAL validator, take its REAL S16 output, push it through
# the REAL normalizer, and confirm the scan branch condition (`= true`) selects
# INCLUDE_VENV. This is the exact path that failed in v7.
if [ -x "$PY" ] || command -v "$PY" >/dev/null 2>&1; then
  vout="$("$PY" "$VALIDATOR" "$DECISIONS" 2>&1)"; vrc=$?
  if [ "$vrc" -eq 0 ]; then
    raw="$(printf '%s\n' "$vout" | sed -n 's/^s16_scan_includes_venv=//p')"
    norm="$(g3_norm_bool "$raw")"
    if [ "$norm" = "true" ]; then
      ok "QW-04 validator->normalize->scan selects INCLUDE_VENV (raw='$raw')"
    else
      no "QW-04 validator output '$raw' normalized to '$norm', not true"
    fi
    # Negative: an invalid decision artifact must still be rejected by the
    # validator (fail-closed preserved).
    bad="$TMP/bad.json"; cp "$DECISIONS" "$bad"
    sed -i 's/"maximum_runtime_seconds": 2700/"maximum_runtime_seconds": 600/' "$bad"
    if "$PY" "$VALIDATOR" "$bad" >/dev/null 2>&1; then
      no "QW-04 invalid decision artifact must be rejected"
    else ok "QW-04 invalid decision artifact still rejected (fail-closed)"; fi
  else
    no "QW-04 real validator failed on the packaged decision artifact: $vout"
  fi
else
  no "QW-04 no usable Python interpreter ($PY); end-to-end check not performed"
fi

# =============================================================================
# QW-02 : S7 complete hash-error accounting (real g3_hash_account)
# =============================================================================
echo
echo "== QW-02 S7 hash-error accounting =="

mkfixture(){ # tracked_list manifest_lines -> writes $TMP/tracked.z $TMP/m.sha
  : > "$TMP/tracked.z"
  : > "$TMP/m.sha"
  local i=0
  for f in $1; do
    printf '%s\0' "$f" >> "$TMP/tracked.z"
    i=$((i+1))
  done
  local n=0
  for line in $2; do
    n=$((n+1))
    printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "$line" >> "$TMP/m.sha"
  done
}

AUTH="cai_service cloak_service mcp_hub mhddos_service"

# Case A: exactly the four authorized -> unhashed set == authorized -> PASS.
mkfixture "$AUTH" ""
unh="$(g3_hash_account "$TMP/tracked.z" "$TMP/m.sha" /dev/null)"
printf '%s\n' $AUTH | sort > "$TMP/auth.txt"
printf '%s\n' "$unh" | sort > "$TMP/obs.txt"
if g3_s7_set_equal "$TMP/obs.txt" "$TMP/auth.txt"; then
  ok "QW-02 four authorized failures == authorized set (integrity allowed)"
else no "QW-02 authorized case rejected unexpectedly"; fi

# Case B: the four PLUS a permission-denied / io-error / symlink-loop entry
# that does NOT say 'No such file or directory' -> MUST be detected as unexpected.
for extra in secret_mode_0 file_io_err symlink_loop_a; do
  mkfixture "$AUTH $extra" ""
  unh="$(g3_hash_account "$TMP/tracked.z" "$TMP/m.sha" /dev/null)"
  printf '%s\n' "$unh" | sort > "$TMP/obs.txt"
  if g3_s7_set_equal "$TMP/obs.txt" "$TMP/auth.txt"; then
    no "QW-02 unexpected extra '$extra' was NOT detected (false PASS)"
  else
    ok "QW-02 unexpected extra '$extra' detected (no false integrity PASS)"
  fi
done

# Case C: a tracked file that hashed fine is NOT counted as a failure.
mkfixture "$AUTH good.txt" "good.txt"
unh="$(g3_hash_account "$TMP/tracked.z" "$TMP/m.sha" /dev/null)"
if printf '%s\n' "$unh" | grep -qx 'good.txt'; then
  no "QW-02 successfully hashed file wrongly counted as unhashed"
else ok "QW-02 successfully hashed file excluded from unhashed set"; fi

# Case D: missing authorized entry -> set differs -> rejected.
mkfixture "cai_service cloak_service mcp_hub" ""
unh="$(g3_hash_account "$TMP/tracked.z" "$TMP/m.sha" /dev/null)"
printf '%s\n' "$unh" | sort > "$TMP/obs.txt"
if g3_s7_set_equal "$TMP/obs.txt" "$TMP/auth.txt"; then
  no "QW-02 missing authorized entry NOT detected"
else ok "QW-02 missing authorized entry detected"; fi

# Case E: incomplete/failed enumeration inputs must fail closed.
if g3_hash_account "$TMP/nonexistent.z" "$TMP/m.sha" /dev/null >/dev/null 2>&1; then
  no "QW-02 missing tracked-list must fail closed"
else ok "QW-02 missing tracked-list fails closed"; fi
if g3_hash_account "$TMP/tracked.z" "$TMP/nonexistent.sha" /dev/null >/dev/null 2>&1; then
  no "QW-02 missing manifest must fail closed"
else ok "QW-02 missing manifest fails closed"; fi

# Case F: filenames with spaces are handled (no dropped records).
sp="dir with space/file name.txt"
mkfixture "$AUTH" ""
: > "$TMP/tracked.z"
printf '%s\0' "$sp" >> "$TMP/tracked.z"
unh="$(g3_hash_account "$TMP/tracked.z" "$TMP/m.sha" /dev/null)"
if [ "$unh" = "$sp" ]; then ok "QW-02 filename with spaces accounted exactly"; else no "QW-02 space filename -> '$unh'"; fi

# =============================================================================
# QW-03 : authorized-set digest is descriptive only
# =============================================================================
echo
echo "== QW-03 descriptive digest =="
printf '%s\n' $AUTH | sort > "$TMP/auth.txt"
d1="$(g3_s7_descriptive_digest "$TMP/auth.txt")"
d2="$(g3_s7_descriptive_digest "$TMP/auth.txt")"
[ -n "$d1" ] && [ "$d1" = "$d2" ] && ok "QW-03 descriptive digest is stable ($d1)" || no "QW-03 digest unstable"

# =============================================================================
echo
echo "-------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]