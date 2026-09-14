#!/usr/bin/env bash
# Minimal test harness. Source this, then use `it`, `ok`, `no`, `eq`, `has`.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""
FAILURES=""

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_DIR

# Each `it` runs in the caller's shell so helpers can set state.
it() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

_pass() { printf '  ok   %s\n' "$CURRENT_TEST"; }
_fail() {
  printf '  FAIL %s\n' "$CURRENT_TEST"
  [ -n "${1:-}" ] && printf '         %s\n' "$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILURES="$FAILURES\n  - $CURRENT_TEST${1:+: $1}"
}

# ok <command...>  — passes if the command succeeds
ok() { if "$@" >/dev/null 2>&1; then _pass; else _fail "command failed: $*"; fi; }

# no <command...>  — passes if the command fails
no() { if "$@" >/dev/null 2>&1; then _fail "expected failure: $*"; else _pass; fi; }

# eq <expected> <actual>
eq() {
  if [ "$1" = "$2" ]; then _pass; else _fail "expected '$1', got '$2'"; fi
}

# has <file> <fixed-string>
has() {
  if grep -Fq "$2" "$1" 2>/dev/null; then _pass; else _fail "'$2' not found in $1"; fi
}

# hasnt <file> <extended-regex>
hasnt() {
  if grep -Eq "$2" "$1" 2>/dev/null; then _fail "'$2' should not match in $1"; else _pass; fi
}

section() { printf '\n%s\n' "$1"; }

summary() {
  printf '\n%s\n' "────────────────────────────────────────"
  if [ "$TESTS_FAILED" -eq 0 ]; then
    printf '%s tests, all passed\n' "$TESTS_RUN"
    return 0
  fi
  printf '%s tests, %s FAILED\n' "$TESTS_RUN" "$TESTS_FAILED"
  printf '%b\n' "$FAILURES"
  return 1
}

# A throwaway HOME that looks like a fresh macOS account with Dropbox synced.
make_fake_home() {
  local fake="$1"
  rm -rf "$fake"
  mkdir -p "$fake/Library/CloudStorage/Dropbox" "$fake/Library/Fonts"
  ln -s "$(dirname "$REPO_DIR")" "$fake/Library/CloudStorage/Dropbox/repositories"
}

# Drive a command that insists on a real terminal (age -p), feeding it lines.
with_tty() {
  local input="$1"; shift
  # Hard timeout: a command that decides to prompt again must fail the test,
  # never wedge the suite.
  if command -v timeout >/dev/null 2>&1; then
    printf '%b' "$input" | timeout 20 script -q /dev/null "$@" >/dev/null 2>&1
  else
    printf '%b' "$input" | script -q /dev/null "$@" >/dev/null 2>&1
  fi
}

# Run a command with a clean environment, as a fresh login shell would.
in_fake_home() {
  local fake="$1"; shift
  env -i HOME="$fake" PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm "$@"
}
