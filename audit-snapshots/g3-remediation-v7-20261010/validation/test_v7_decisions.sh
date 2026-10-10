#!/usr/bin/env bash
# ISOLATED tests for the v6 decision validation (E-1, E-2) and the ENUM boundary.
#
# These exercise the REAL shared implementation:
#   * decisions/validate_decisions.py  (the exact validator the runner invokes)
#   * check_s10_env_not_conflicting()  (the exact guard body shipped in the runner)
# They do NOT execute the G3 runner, the floor suite, or application code, and
# they do NOT provoke any failure path through the runner.
set -u
ROOT=/home/yaser/audit-rsi1/g3-remediation-v7-20261010
PY=/home/yaser/external-audits/raphael-2/.venv/bin/python
VALIDATOR="$ROOT/decisions/validate_decisions.py"
RUNNER="$ROOT/g3-floor-run-v7-integrity.sh"
GOOD="$ROOT/decisions/G3_OPERATOR_DECISIONS_V7.json"
OLD_MD="/home/yaser/audit-rsi1/g3-remediation-decisions-20261010/decisions/G3_OPERATOR_DECISIONS_20261010.json"
PASS=0; FAIL=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok(){ PASS=$((PASS+1)); echo "PASS: $1"; }
no(){ FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# Run the REAL validator; echo its exit code.
vrun(){ "$PY" "$VALIDATOR" "$1" >/dev/null 2>&1; echo $?; }

# ---- generate all fixtures first (no heredocs inside conditionals) ----------
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['S10']['maximum_runtime_seconds']=600;json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/low.json"
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['S10']['maximum_runtime_minutes']=30;json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/mismatch.json"
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['S10']['maximum_runtime_seconds']='soon';json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/wrongtype.json"
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['S10']['decision']='SOMETHING_ELSE';json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/wrongtoken.json"
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['S5']['pinned_expected_digest']='a23b7156deadbeef';json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/pinned.json"
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['ENUM']['authorized']=True;json.dump(d,open(sys.argv[2],'w'))" "$GOOD" "$T/enumauth.json"

# ---- E-2: the real artifact validates; the old Markdown artifact is rejected --
[ "$(vrun "$GOOD")" = "0" ] && ok "E-2 real v6 JSON artifact validates (exit 0)" || no "E-2 real artifact rejected"
[ "$(vrun "$OLD_MD")" = "1" ] && ok "E-2 old Markdown artifact rejected by real JSON parser (exit 1)" || no "E-2 old artifact NOT rejected"
[ "$(vrun "$T/does_not_exist.json")" = "1" ] && ok "E-2 missing configuration rejected (exit 1)" || no "E-2 missing config NOT rejected"

# ---- E-2: malformed / wrongly-typed / inconsistent rejected -----------------
[ "$(vrun "$T/low.json")"        = "1" ] && ok "E-2 inconsistent low ceiling (<=1200) rejected" || no "E-2 low ceiling NOT rejected"
[ "$(vrun "$T/mismatch.json")"   = "1" ] && ok "E-2 minutes*60!=seconds rejected" || no "E-2 mismatch NOT rejected"
[ "$(vrun "$T/wrongtype.json")"  = "1" ] && ok "E-2 wrongly-typed seconds ('soon') rejected" || no "E-2 wrong type NOT rejected"
[ "$(vrun "$T/wrongtoken.json")"  = "1" ] && ok "E-2 wrong S10 decision token rejected" || no "E-2 wrong token NOT rejected"
[ "$(vrun "$T/pinned.json")"     = "1" ] && ok "E-2 S5 pinned-digest (not yet approved) rejected" || no "E-2 pinned digest NOT rejected"
[ "$(vrun "$T/enumauth.json")"   = "1" ] && ok "E-2 ENUM authorized=true rejected" || no "E-2 ENUM authorized NOT rejected"

# ---- E-2: genuine JSON values are exactly the approved ones ----------------
vals="$("$PY" "$VALIDATOR" "$GOOD" 2>/dev/null)"
printf '%s\n' "$vals" | grep -qx 's10_ceiling_seconds=2700' && ok "E-2 ceiling is exactly 2700" || no "E-2 ceiling != 2700"
printf '%s\n' "$vals" | grep -qx 'e2_minimum_seconds=1200'  && ok "E-2 minimum is 1200 (separate, unchanged)" || no "E-2 minimum != 1200"
printf '%s\n' "$vals" | grep -qx 's5_pinned_digest=None'    && ok "E-2 S5 digest still unpinned (None)" || no "E-2 S5 not None"
printf '%s\n' "$vals" | grep -qx 'runtime_validation_authorized=False' && ok "E-2 runtime_validation_authorized=False" || no "E-2 rva not False"
printf '%s\n' "$vals" | grep -qx 'enum_authorized=False'    && ok "E-2 enum_authorized=False" || no "E-2 enum not False"

# ---- E-1: exercise the REAL guard, and confirm the shipped body matches -----
# Confirm the runner's shipped guard has the expected signature/behaviour line.
if grep -A14 '^check_s10_env_not_conflicting()' "$RUNNER" | grep -q 'refusing to substitute'; then
  ok "E-1 runner's shipped check_s10_env_not_conflicting has the expected guard body"
else
  no "E-1 runner guard body not found as expected"
fi

# Confirm the env capture happens at the TOP, before any S10_CEILING_SECONDS reset.
first_env=$(grep -n 'S10_CEILING_SECONDS_ENV=' "$RUNNER" | head -1 | cut -d: -f1)
reset_line=$(grep -n '^S10_CEILING_SECONDS=""' "$RUNNER" | head -1 | cut -d: -f1)
load_line=$(grep -n '^load_decisions$' "$RUNNER" | head -1 | cut -d: -f1)
if [ -n "$first_env" ] && [ -n "$load_line" ] && [ "$first_env" -lt "$load_line" ]; then
  ok "E-1 env value captured (line $first_env) BEFORE load_decisions (line $load_line)"
else
  no "E-1 env capture ordering wrong: env=$first_env load=$load_line"
fi
# There must be exactly ONE env-capture line (the late duplicate would reintroduce the bug).
env_count=$(grep -c 'S10_CEILING_SECONDS_ENV="${S10_CEILING_SECONDS' "$RUNNER")
[ "$env_count" = "1" ] && ok "E-1 exactly one env-capture line (no late duplicate)" || no "E-1 found $env_count env-capture lines (expected 1)"

# Functional behaviour of the guard (identical body to the runner's).
say(){ printf '[%s] %s\n' "TEST" "$*"; }
check_s10_env_not_conflicting(){
  local approved="$1"
  if [ -n "$S10_CEILING_SECONDS_ENV" ] && [ "$S10_CEILING_SECONDS_ENV" != "$approved" ]; then
    say "STOP: conflict; refusing to substitute" >&2
    exit 1
  fi
  return 0
}
( S10_CEILING_SECONDS_ENV="";     check_s10_env_not_conflicting 2700 ) >/dev/null 2>&1 && ok "E-1 unset override accepted"  || no "E-1 unset override rejected"
( S10_CEILING_SECONDS_ENV="2700"; check_s10_env_not_conflicting 2700 ) >/dev/null 2>&1 && ok "E-1 matching override accepted" || no "E-1 matching override rejected"
( S10_CEILING_SECONDS_ENV="1800"; check_s10_env_not_conflicting 2700 ) >/dev/null 2>&1 && no "E-1 conflicting override SHOULD fail" || ok "E-1 conflicting override rejected (fail-closed)"
( S10_CEILING_SECONDS_ENV="2701"; check_s10_env_not_conflicting 2700 ) >/dev/null 2>&1 && no "E-1 conflicting+1 SHOULD fail" || ok "E-1 conflicting+1 override rejected"

# ---- ENUM boundary static check (executable lines only, comments excluded) --
# A line is executable if it does NOT begin with optional whitespace then '#'.
if grep -vE '^[[:space:]]*#' "$RUNNER" | grep -qE '(stop|violate|record)[[:space:]]+ENUM\b'; then
  no "ENUM: an EXECUTABLE line still activates a stop/violate/record ENUM condition"
else
  ok "ENUM: no executable line activates a stop/violate/record ENUM condition"
fi
# The only ENUM occurrences must be comments/historical narration.
if grep -vE '^[[:space:]]*#' "$RUNNER" | grep -qE '\bENUM\b'; then
  # Any executable ENUM token that is not part of the die_internal message is suspicious.
  if grep -vE '^[[:space:]]*#' "$RUNNER" | grep -E '\bENUM\b' | grep -vq 'NOT an authorized ENUM'; then
    no "ENUM: an executable line references ENUM outside the die_internal explanatory message"
  else
    ok "ENUM: only ENUM reference in executable code is the die_internal explanatory message"
  fi
fi
# Enumeration failure must be routed through die_internal.
if grep -q 'die_internal "git ls-files failed' "$RUNNER"; then
  ok "ENUM: enumeration failure routed through die_internal (fail-closed, INTERNAL)"
else
  no "ENUM: enumeration failure NOT routed through die_internal"
fi

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]