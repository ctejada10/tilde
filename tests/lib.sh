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

skip() {
  printf '  skip %s\n' "$1"
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

# Record a directory tree precisely enough to prove nothing moved: relative
# path, kind, symlink target, mode, and content hash for regular files.
snapshot() {
  local root="$1"
  ( cd "$root" 2>/dev/null || return 0
    find . -mindepth 1 \( -type f -o -type d -o -type l \) 2>/dev/null | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then
        printf '%s\tlink\t%s\t%s\n' "$p" "$(readlink "$p")" "$(stat -f '%OLp' "$p" 2>/dev/null)"
      elif [ -d "$p" ]; then
        printf '%s\tdir\t-\t%s\n' "$p" "$(stat -f '%OLp' "$p" 2>/dev/null)"
      else
        printf '%s\tfile\t%s\t%s\n' "$p" "$(shasum -a 256 "$p" 2>/dev/null | cut -d" " -f1)" "$(stat -f '%OLp' "$p" 2>/dev/null)"
      fi
    done )
}

# Pass if two snapshot files are identical, otherwise show what moved.
same_snapshot() {
  if diff -u "$1" "$2" > "$SCRATCH/snapdiff.$$" 2>&1; then
    _pass
  else
    _fail "tree changed: $(grep -cE '^[+-][^+-]' "$SCRATCH/snapdiff.$$" || true) line(s) differ; first: $(grep -E '^[+-][^+-]' "$SCRATCH/snapdiff.$$" | head -1 | cut -c1-70)"
  fi
}

# A fresh clone carries no plaintext ssh keys - they are gitignored and live
# encrypted in secrets/. finish.sh correctly reports MISSING and fails in that
# state, so tests that expect a clean run have to unseal first, the same way a
# real restore does when you type the passphrase.
#
# Returns 0 if keys are available (already present, or successfully unsealed).
ensure_secrets_available() {
  local repo="${1:-$REPO_DIR}"
  [ -f "$repo/dotfiles/ssh/.ssh/arnor" ] && return 0
  [ -f "$repo/secrets/ssh.enc.json" ] || return 1
  local key="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
  [ -f "$key" ] || return 1
  env SOPS_AGE_KEY_FILE="$key" TILDE_SSH_DIR="$repo/dotfiles/ssh/.ssh" \
      TILDE_SECRETS_FILE="$repo/secrets/ssh.enc.json" \
      bash "$repo/scripts/secrets.sh" unseal >/dev/null 2>&1
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
  # env -i wipes the environment, so anything the scripts need must be named
  # here — including the stow backup override, or finish.sh's internal .stow
  # call writes backups into the repo.
  env -i HOME="$fake" PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm \
      TILDE_STOW_BACKUP_DIR="${TILDE_STOW_BACKUP_DIR:-$SCRATCH/stow-backups}" "$@"
}
