#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 v8 — decision-validator regression tests (inherited v7 coverage).
#
# QW-06: paths are derived from this script's own location, so the package is
# relocatable and no authoring-machine path is hard-coded. The interpreter may
# be overridden with G3_TEST_PYTHON.
#
# Preserves coverage for: S5 (unpinned digest / inventory completeness), S10
# (2700 s ceiling and the E-1 capture-ordering guard), S16 (INCLUDE_VENV),
# S17 (literal marker retained) and the ENUM authorization boundary.
#
# Does NOT execute the G3 runner, floor suite, or application code.
# =============================================================================
set -uo pipefail

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$PKG"
VALIDATOR="$PKG/decisions/validate_decisions.py"
GOOD="$PKG/decisions/G3_OPERATOR_DECISIONS_V8.json"
RUNNER="$PKG/g3-floor-run-v8-integrity.sh"
PY="${G3_TEST_PYTHON:-python3}"

# The legacy Markdown decision artifact is optional; the test that relies on it
# is skipped when it is not present (the v8 package is self-contained).
LEGACY_V5_MD="$(dirname "$(dirname "$PKG")")/g3-remediation-decisions-20261010/decisions/G3_OPERATOR_DECISIONS_20261010.json"

# shellcheck source=../g3_v8_lib.sh
. "$PKG/g3_v8_lib.sh"

PASS=0; FAIL=0
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
no(){ FAIL=$((FAIL+1)); echo "FAIL: $1"; }

vrun(){ "$PY" "$VALIDATOR" "$1" >/dev/null 2>&1; echo $?; }
# mkjson <python-mutation-expr> : load GOOD, apply mutation, write $T/out.json
mkjson(){ "$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));exec(sys.argv[2]);json.dump(d,open(sys.argv[3],'w'))" "$GOOD" "$1" "$T/out.json"; }

echo "== decision validator (real) =="
[ "$(vrun "$GOOD")" = "0" ] && ok "packaged v8 decision artifact validates" || no "packaged v8 decision artifact rejected"
[ -f "$LEGACY_V5_MD" ] && { [ "$(vrun "$LEGACY_V5_MD")" = "1" ] && ok "legacy Markdown artifact rejected by real JSON parser" || no "legacy Markdown artifact NOT rejected"; } \
                         || echo "SKIP: legacy Markdown artifact not present (self-contained package)"

echo "== S5 inventory (digest must stay unpinned) =="
vals="$("$PY" "$VALIDATOR" "$GOOD" 2>/dev/null)"
printf '%s\n' "$vals" | grep -qx 's5_pinned_digest=None' && ok "S5 pinned digest remains None (unapproved)" || no "S5 pinned digest not None"
mkjson "d['S5']['pinned_expected_digest']='deadbeef'"
[ "$(vrun "$T/out.json")" = "1" ] && ok "S5 pinned digest is rejected" || no "S5 pinned digest NOT rejected"

echo "== S10 ceiling + E-2 minimum =="
printf '%s\n' "$vals" | grep -qx 's10_ceiling_seconds=2700' && ok "S10 ceiling is 2700" || no "S10 ceiling != 2700"
printf '%s\n' "$vals" | grep -qx 'e2_minimum_seconds=1200' && ok "E-2 minimum is 1200 (separate)" || no "E-2 minimum != 1200"
mkjson "d['S10']['maximum_runtime_seconds']=600"
[ "$(vrun "$T/out.json")" = "1" ] && ok "inconsistent low ceiling rejected" || no "low ceiling NOT rejected"
mkjson "d['S10']['maximum_runtime_minutes']=30"
[ "$(vrun "$T/out.json")" = "1" ] && ok "minutes*60!=seconds rejected" || no "mismatch NOT rejected"

echo "== S16 / S17 / runtime flag =="
printf '%s\n' "$vals" | grep -qx 's16_scan_includes_venv=True' && ok "validator reports S16 True" || no "S16 not True"
printf '%s\n' "$vals" | grep -qx 's17_marker_condition=retained' && ok "S17 marker retained" || no "S17 marker not retained"
printf '%s\n' "$vals" | grep -qx 'runtime_validation_authorized=False' && ok "runtime_validation_authorized False" || no "rva not False"
mkjson "d['S16']['repository_scan_includes_venv']=False"
[ "$(vrun "$T/out.json")" = "1" ] && ok "S16 venv=false rejected" || no "S16 venv=false NOT rejected"

echo "== ENUM authorization boundary =="
printf '%s\n' "$vals" | grep -qx 'enum_authorized=False' && ok "ENUM unauthorized in decision" || no "ENUM not False"
mkjson "d['ENUM']['authorized']=True"
[ "$(vrun "$T/out.json")" = "1" ] && ok "ENUM authorized=true rejected" || no "ENUM authorized NOT rejected"
# The runner must not activate an EXECUTABLE ENUM stop condition.
if grep -vE '^[[:space:]]*#' "$RUNNER" | grep -qE '(stop|violate|record)[[:space:]]+ENUM\b'; then
  no "runner still activates an ENUM condition"
else ok "runner has no executable stop/violate/record ENUM"; fi
grep -q 'die_internal "git ls-files failed' "$RUNNER" && ok "enumeration failure routed via die_internal" || no "enumeration not routed via die_internal"

echo "== E-1 S10 env capture ordering (source inspection of the real runner) =="
first_env=$(grep -n 'S10_CEILING_SECONDS_ENV="${S10_CEILING_SECONDS' "$RUNNER" | head -1 | cut -d: -f1)
load_line=$(grep -n '^load_decisions$' "$RUNNER" | head -1 | cut -d: -f1)
env_count=$(grep -c 'S10_CEILING_SECONDS_ENV="${S10_CEILING_SECONDS' "$RUNNER")
if [ -n "$first_env" ] && [ -n "$load_line" ] && [ "$first_env" -lt "$load_line" ]; then
  ok "env captured (line $first_env) before load_decisions (line $load_line)"
else no "env capture ordering wrong: env=$first_env load=$load_line"; fi
[ "$env_count" = "1" ] && ok "exactly one env-capture line" || no "found $env_count env-capture lines"

echo
echo "-------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]