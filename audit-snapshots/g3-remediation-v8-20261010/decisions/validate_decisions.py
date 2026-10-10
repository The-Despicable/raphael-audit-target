#!/usr/bin/env python3
"""RAPHAEL G3 v6 — Operator-decision validator (shared implementation).

This is the SINGLE source of truth for parsing and validating the operator
decision artifact. It is invoked by the v6 runner AND by the isolated tests,
so the tests exercise the real implementation rather than a replica.

Uses Python's standard-library json module (no external dependencies).
Fail-closed: raises DecisionError on any missing, malformed, wrongly-typed or
internally inconsistent field.
"""
import json
import sys

# Authorized decision tokens (from the operator decision record).
EXPECTED_S10_DECISION = "SET_EXPLICIT_MAXIMUM"
EXPECTED_S16_DECISION = "INCLUDE_VENV"
EXPECTED_S17_DECISION = "RETAIN_LITERAL_MARKER_CONDITION"

# The unchanged E-2 minimum (floor on available time; never a ceiling).
E2_MINIMUM_SECONDS = 1200


class DecisionError(Exception):
    """Raised for any missing, malformed, wrongly-typed or inconsistent field."""


def _require(cond, msg):
    if not cond:
        raise DecisionError(msg)


def _get(d, key, typ, where):
    _require(isinstance(d, dict), f"{where}: expected an object")
    _require(key in d, f"{where}: missing required field '{key}'")
    val = d[key]
    _require(isinstance(val, typ) and not isinstance(val, bool) if typ is int else isinstance(val, typ),
             f"{where}: field '{key}' has wrong type (expected {typ.__name__}, got {type(val).__name__})")
    return val


def load_decisions(path):
    """Load and fully validate the decision artifact. Returns a dict.
    Raises DecisionError on any problem (caller must fail closed)."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read()
    except OSError as exc:
        raise DecisionError(f"decision artifact missing or unreadable: {exc}")

    # Genuine JSON parse (not regex). Rejects Markdown and any other non-JSON.
    try:
        d = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise DecisionError(f"decision artifact is not valid JSON: {exc}")

    _require(isinstance(d, dict), "decision artifact root must be a JSON object")

    out = {}

    # --- S10 -------------------------------------------------------------
    s10 = d.get("S10")
    _require(isinstance(s10, dict), "S10: missing or not an object")
    s10_decision = _get(s10, "decision", str, "S10")
    _require(s10_decision == EXPECTED_S10_DECISION,
             f"S10.decision is '{s10_decision}', expected '{EXPECTED_S10_DECISION}'")
    max_min = _get(s10, "maximum_runtime_minutes", int, "S10")
    max_sec = _get(s10, "maximum_runtime_seconds", int, "S10")
    e2_min = _get(s10, "e2_minimum_seconds", int, "S10")
    # internal consistency: minutes*60 must equal seconds
    _require(max_min * 60 == max_sec,
             f"S10 inconsistent: maximum_runtime_minutes*60 ({max_min*60}) != maximum_runtime_seconds ({max_sec})")
    # the ceiling must exceed the unchanged minimum
    _require(max_sec > e2_min,
             f"S10 inconsistent: ceiling ({max_sec}) must exceed the E-2 minimum ({e2_min})")
    _require(e2_min == E2_MINIMUM_SECONDS,
             f"S10.e2_minimum_seconds is {e2_min}, expected the unchanged {E2_MINIMUM_SECONDS}")
    s10_rva = _get(s10, "runtime_validation_authorized", bool, "S10")
    _require(s10_rva is False,
             "S10.runtime_validation_authorized must be false; recording a ceiling does not authorize execution")
    out["s10_ceiling_seconds"] = max_sec
    out["e2_minimum_seconds"] = e2_min

    # --- S16 -------------------------------------------------------------
    s16 = d.get("S16")
    _require(isinstance(s16, dict), "S16: missing or not an object")
    s16_decision = _get(s16, "decision", str, "S16")
    _require(s16_decision == EXPECTED_S16_DECISION,
             f"S16.decision is '{s16_decision}', expected '{EXPECTED_S16_DECISION}'")
    repo_venv = _get(s16, "repository_scan_includes_venv", bool, "S16")
    wt_venv = _get(s16, "worktree_scan_includes_venv", bool, "S16")
    _require(repo_venv is True, "S16.repository_scan_includes_venv must be true under INCLUDE_VENV")
    _require(wt_venv is True, "S16.worktree_scan_includes_venv must be true under INCLUDE_VENV")
    out["s16_scan_includes_venv"] = True

    # --- S17 -------------------------------------------------------------
    s17 = d.get("S17")
    _require(isinstance(s17, dict), "S17: missing or not an object")
    s17_decision = _get(s17, "decision", str, "S17")
    _require(s17_decision == EXPECTED_S17_DECISION,
             f"S17.decision is '{s17_decision}', expected '{EXPECTED_S17_DECISION}'")
    _require(_get(s17, "actual_scope_failure_carrier", str, "S17") == "S6",
             "S17.actual_scope_failure_carrier must be 'S6'")
    _require(_get(s17, "s17_does_not_independently_define_scope_failure", bool, "S17") is True,
             "S17.s17_does_not_independently_define_scope_failure must be true")
    out["s17_marker_condition"] = "retained"

    # --- S5 (must remain unpinned until approved) ------------------------
    s5 = d.get("S5")
    _require(isinstance(s5, dict), "S5: missing or not an object")
    _require(_get(s5, "status", str, "S5") == "PENDING_OPERATOR_APPROVAL",
             "S5.status must be PENDING_OPERATOR_APPROVAL until explicitly approved")
    pinned = s5.get("pinned_expected_digest", "MISSING")
    _require(pinned is None or pinned == "MISSING",
             "S5.pinned_expected_digest must be null/unset until the operator explicitly approves a digest")
    out["s5_pinned_digest"] = None

    # --- ENUM must remain unauthorized ------------------------------------
    enum = d.get("ENUM")
    _require(isinstance(enum, dict), "ENUM: missing or not an object")
    _require(_get(enum, "status", str, "ENUM") == "PROPOSED_NOT_AUTHORIZED",
             "ENUM.status must be PROPOSED_NOT_AUTHORIZED")
    _require(_get(enum, "authorized", bool, "ENUM") is False,
             "ENUM.authorized must be false until the authority approves the proposal")
    _require(_get(enum, "enforced_in_runner", bool, "ENUM") is False,
             "ENUM.enforced_in_runner must be false; the runner must not enforce an unauthorized condition")
    out["enum_authorized"] = False

    # --- top-level runtime validation flag --------------------------------
    rva = d.get("runtime_validation_authorized")
    _require(rva is False, "runtime_validation_authorized must be false")
    out["runtime_validation_authorized"] = False

    return out


def main():
    if len(sys.argv) != 2:
        print("usage: validate_decisions.py <decisions.json>", file=sys.stderr)
        return 2
    try:
        out = load_decisions(sys.argv[1])
    except DecisionError as exc:
        print(f"DECISION_ERROR: {exc}", file=sys.stderr)
        return 1
    print("DECISION_OK")
    for k, v in out.items():
        print(f"{k}={v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())