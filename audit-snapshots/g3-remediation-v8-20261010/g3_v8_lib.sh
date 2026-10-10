#!/usr/bin/env bash
# =============================================================================
# RAPHAEL G3 — v8 shared control library (side-effect-free helpers)
# =============================================================================
# This library holds the *production* logic for the controls remediated in v8:
#
#   QW-01  S14 artifact-isolation canonicalization + containment
#   QW-02  S7 hash-error accounting (complete, not ENOENT-only)
#   QW-04  S16 decision-boolean normalization at the validator/shell boundary
#   QW-03  S7 authorization-set comparison (digest is DESCRIPTIVE only)
#
# The runner sources this file, and the regression tests source the SAME file.
# Tests therefore exercise real production behaviour, not a re-created
# approximation. Nothing in this file executes the runner, the floor suite or
# application code; every function is pure with respect to the filesystem
# except where a path must exist for canonicalization.
#
# Design constraints honoured here:
#   * Canonicalization uses `realpath -m` (GNU coreutils), which resolves
#     `..`, `/./`, repeated and trailing separators, symlinks, and NON-existent
#     tails. If it is unavailable or fails, callers must fail closed.
#   * S7 accounting is derived from the hash tool's *structured* output when
#     available, and never from a text match that can silently drop records.
# =============================================================================

# -----------------------------------------------------------------------------
# g3_realpath_m <path>
#   Canonicalize <path> to an absolute path WITHOUT requiring it to exist.
#   Echoes the canonical path on success.
#   Returns 1 (fail closed) if realpath is unavailable or cannot canonicalize.
# -----------------------------------------------------------------------------
g3_realpath_m() {
  local p="${1:-}"
  [ -n "$p" ] || return 1
  # realpath -m resolves symlinks for existing components and tolerates a
  # non-existent tail; it never fails merely because the target is missing.
  if command -v realpath >/dev/null 2>&1; then
    local out
    out="$(realpath -m -- "$p" 2>/dev/null)" || return 1
    [ -n "$out" ] || return 1
    printf '%s\n' "$out"
    return 0
  fi
  # No realpath: fail closed rather than fall back to unsafe lexical cleanup.
  return 1
}

# -----------------------------------------------------------------------------
# g3_contains <inner> <outer>
#   Return 0 (true) when <inner> is inside OR equal to <outer>, using already
#   canonical absolute paths. Pure string containment on canonical inputs.
# -----------------------------------------------------------------------------
g3_contains() {
  local inner="$1" outer="$2"
  [ -n "$inner" ] && [ -n "$outer" ] || return 1
  if [ "$inner" = "$outer" ]; then
    return 0
  fi
  case "$inner/" in
    "$outer"/*) return 0 ;;
  esac
  return 1
}

# -----------------------------------------------------------------------------
# g3_norm_path <path>
#   QW-01 corrected normalization: produce a canonical absolute path.
#   Returns 1 if canonicalization is unavailable/unsafe (fail closed).
# -----------------------------------------------------------------------------
g3_norm_path() {
  g3_realpath_m "$1"
}

# -----------------------------------------------------------------------------
# g3_s14_boundary_violation <artifact_dir> <protected_dir>
#   QW-01 corrected containment test. Echoes a reason and returns 0 when the
#   artifact destination is UNSAFE (inside/equal a protected location, or a
#   protected location inside/equal the artifact destination). Returns 1 when
#   the boundary is safe. Fails closed (returns 0 with a reason) when paths
#   cannot be canonicalized.
# -----------------------------------------------------------------------------
g3_s14_boundary_violation() {
  local art="$1" prot="$2"
  local nart nprot
  nart="$(g3_norm_path "$art")" || { printf 'ART_CANNOT_CANONICALIZE:%s\n' "$art"; return 0; }
  nprot="$(g3_norm_path "$prot")" || { printf 'PROTECTED_CANNOT_CANONICALIZE:%s\n' "$prot"; return 0; }
  if g3_contains "$nart" "$nprot"; then
    printf 'ART_INSIDE_PROTECTED:%s|%s\n' "$nart" "$nprot"
    return 0
  fi
  if g3_contains "$nprot" "$nart"; then
    printf 'PROTECTED_INSIDE_ART:%s|%s\n' "$nprot" "$nart"
    return 0
  fi
  return 1
}

# -----------------------------------------------------------------------------
# g3_norm_bool <value>
#   QW-04 corrected boolean normalization at the validator/shell boundary.
#   The Python validator prints Python bools ("True"/"False"); the shell scans
#   compare lowercase. Map Python bools and lowercase to a canonical lowercase
#   "true"/"false". Anything else is ambiguous and returns 1 (fail closed).
# -----------------------------------------------------------------------------
g3_norm_bool() {
  local v="${1:-}"
  case "$v" in
    True|true|TRUE) printf 'true\n'; return 0 ;;
    False|false|FALSE) printf 'false\n'; return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# g3_hash_account <tracked_zfile> <manifest_file> <stderr_file>
#   QW-02 corrected hash-error accounting.
#
#   Computes the COMPLETE set of tracked paths that were NOT successfully
#   hashed, by comparing the enumerated tracked set (NUL-delimited) against the
#   paths that appear in the sha256sum manifest. This is derived from the
#   structured manifest, NOT from parsing an English error string, so a
#   permission-denied, I/O error, or symlink-loop failure is captured exactly
#   like a missing file. No record can silently disappear.
#
#   Writes one normalized (relative, slash) path per line to stdout, sorted.
#   Returns 0 on success; returns 1 if the manifest or tracked list is missing.
# -----------------------------------------------------------------------------
g3_hash_account() {
  local tracked="$1" manifest="$2" _err="${3:-}"
  [ -f "$tracked" ] || return 1
  [ -f "$manifest" ] || return 1

  # Paths successfully hashed = field 2.. of each manifest line (sha256sum
  # emits "<hash><two spaces><path>"). Extract, NUL-safe via the raw bytes.
  # Strip any '*' binary-mode marker and any leading backslash escapes that
  # sha256sum adds for names containing backslashes/newlines.
  sed -E 's/^[0-9a-f]{64} [ *]//' "$manifest" \
    | sed -e 's/^\\//' \
    | LC_ALL=C sort -u > "${manifest}.hashed.paths"

  # All tracked paths, NUL -> newline, sorted.
  tr '\0' '\n' < "$tracked" | sed -e '/^$/d' | LC_ALL=C sort -u > "${tracked}.all.paths"

  # Unhashed = tracked minus successfully-hashed (set difference, not text match).
  LC_ALL=C comm -23 "${tracked}.all.paths" "${manifest}.hashed.paths"
  return 0
}

# -----------------------------------------------------------------------------
# g3_s7_set_equal <observed_file> <authorized_file>
#   QW-02/QW-03 corrected authorization comparison: exact normalized set
#   equality between the OBSERVED unhashed set and the AUTHORIZED literal set.
#   The authorized set is a caller-supplied literal; it is NEVER derived from
#   the observed set. Returns 0 when the two sets are identical.
# -----------------------------------------------------------------------------
g3_s7_set_equal() {
  local observed="$1" authorized="$2"
  [ -f "$observed" ] && [ -f "$authorized" ] || return 1
  LC_ALL=C sort -u "$observed" > "${observed}.s"
  LC_ALL=C sort -u "$authorized" > "${authorized}.s"
  cmp -s "${observed}.s" "${authorized}.s"
}

# -----------------------------------------------------------------------------
# g3_s7_descriptive_digest <authorized_file>
#   QW-03: compute a DESCRIPTIVE fingerprint of the authorized set. This is
#   evidence for humans only; it is NOT an enforcement input and must never be
#   presented as one. Enforcement is g3_s7_set_equal (exact set equality) plus
#   the raw before/after diff.
# -----------------------------------------------------------------------------
g3_s7_descriptive_digest() {
  local authorized="$1"
  [ -f "$authorized" ] || return 1
  LC_ALL=C sort -u "$authorized" | sha256sum | cut -d' ' -f1
}