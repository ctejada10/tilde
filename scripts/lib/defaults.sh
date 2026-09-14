#!/usr/bin/env bash
#
# Idempotent, reportable wrappers around `defaults write`.
#
# `defaults write` is unconditional and silent: run the macOS script and you
# learn nothing about what it actually changed. These read the current value
# first, only write on a difference, and keep a tally.
#
# Set DEFAULTS_CHECK=1 for a dry run that reports what would change.

DEFAULTS_CHANGED=0
DEFAULTS_UNCHANGED=0
DEFAULTS_FORCED=0
DEFAULTS_CHECK="${DEFAULTS_CHECK:-0}"
DEFAULTS_UNREADABLE="__tilde_unreadable__"
DEFAULTS_UNKNOWN=0

# Normalise a value so "true"/"YES"/1 compare equal to what `defaults read`
# gives back for a boolean (which is 1 or 0).
_defaults_norm() {
  case "$1" in
    bool)
      case "$2" in
        true|TRUE|True|yes|YES|Yes|1) printf '1' ;;
        *)                            printf '0' ;;
      esac ;;
    *) printf '%s' "$2" ;;
  esac
}

_defaults_read() {
  case "$1" in
    user) defaults read "$2" "$3" 2>/dev/null ;;
    host) defaults -currentHost read "$2" "$3" 2>/dev/null ;;
    sudo)
      # A failed sudo read must not look like an unset value, or every
      # system-domain setting is reported as drift.
      if sudo -n true 2>/dev/null; then
        sudo -n defaults read "$2" "$3" 2>/dev/null
      else
        printf '%s' "$DEFAULTS_UNREADABLE"
      fi ;;
  esac
}

_defaults_write() {
  case "$1" in
    user) defaults write "$2" "$3" "-$4" "$5" ;;
    host) defaults -currentHost write "$2" "$3" "-$4" "$5" ;;
    sudo) sudo defaults write "$2" "$3" "-$4" "$5" ;;
  esac
}

_defaults_apply() {
  local mode="$1" domain="$2" key="$3" type="$4" value="$5"
  local current want

  current="$(_defaults_read "$mode" "$domain" "$key")"
  if [ "$current" = "$DEFAULTS_UNREADABLE" ]; then
    printf '  ?          %s %s (needs sudo to read)\n' "$domain" "$key"
    DEFAULTS_UNKNOWN=$((DEFAULTS_UNKNOWN + 1))
    return 0
  fi
  current="$(_defaults_norm "$type" "$current")"
  want="$(_defaults_norm "$type" "$value")"

  if [ "$current" = "$want" ]; then
    DEFAULTS_UNCHANGED=$((DEFAULTS_UNCHANGED + 1))
    return 0
  fi

  if [ "$DEFAULTS_CHECK" = "1" ]; then
    printf '  would set  %s %s = %s (now: %s)\n' \
      "$domain" "$key" "$want" "${current:-unset}"
    DEFAULTS_CHANGED=$((DEFAULTS_CHANGED + 1))
    return 0
  fi

  if _defaults_write "$mode" "$domain" "$key" "$type" "$value"; then
    printf '  set        %s %s = %s\n' "$domain" "$key" "$want"
    DEFAULTS_CHANGED=$((DEFAULTS_CHANGED + 1))
  else
    printf '  FAILED     %s %s\n' "$domain" "$key" >&2
  fi
}

# defaults_set <domain> <key> <type> <value>
defaults_set()      { _defaults_apply user "$@"; }
defaults_set_host() { _defaults_apply host "$@"; }
defaults_set_sudo() { _defaults_apply sudo "$@"; }

# For writes that cannot be compared cheaply (-dict-add, untyped values).
# Runs the whole command as given.
defaults_always() {
  DEFAULTS_FORCED=$((DEFAULTS_FORCED + 1))
  if [ "$DEFAULTS_CHECK" = "1" ]; then
    printf '  would run  %s\n' "$*"
    return 0
  fi
  "$@"
}

# Run a side-effecting command, unless this is a dry run. Use for anything
# that changes the system but is not a `defaults` write.
run() {
  if [ "$DEFAULTS_CHECK" = "1" ]; then
    printf '  would run  %s\n' "$*"
    return 0
  fi
  "$@"
}

defaults_summary() {
  printf '\n%s\n' "────────────────────────────────────────"
  if [ "$DEFAULTS_CHECK" = "1" ]; then
    printf 'dry run: %s would change, %s already correct, %s applied unconditionally, %s unreadable\n' \
      "$DEFAULTS_CHANGED" "$DEFAULTS_UNCHANGED" "$DEFAULTS_FORCED" "$DEFAULTS_UNKNOWN"
  else
    printf 'defaults: %s changed, %s already correct, %s applied unconditionally\n' \
      "$DEFAULTS_CHANGED" "$DEFAULTS_UNCHANGED" "$DEFAULTS_FORCED"
  fi
}
