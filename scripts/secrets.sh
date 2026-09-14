#!/usr/bin/env bash
#
# Keep the SSH keys in git, encrypted, instead of relying on Dropbox.
#
#   secrets.sh status     what is configured right now
#   secrets.sh seal       encrypt dotfiles/ssh/.ssh into secrets/ (old machine)
#   secrets.sh unseal     decrypt secrets/ back into dotfiles/ssh/.ssh (new machine)
#   secrets.sh op-store   save the age key to 1Password (do this before wiping)
#   secrets.sh op-fetch   pull the age key from 1Password onto this machine
#   secrets.sh lock-key   encrypt the age key with a passphrase you memorise
#   secrets.sh unlock-key restore the age key by typing that passphrase
#   secrets.sh bootstrap  get the age key by any means, then unseal
#
# The chain is: 1Password holds the age key -> the age key decrypts secrets/ ->
# secrets/ holds the SSH keys. 1Password is the only thing you have to sign
# into by hand, and that sign-in cannot be automated (see op_signin below).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_FILE="${TILDE_SECRETS_FILE:-$REPO_DIR/secrets/ssh.enc.json}"
LOCKED_KEY="${TILDE_LOCKED_KEY:-$REPO_DIR/secrets/age-key.age}"
SSH_DIR="${TILDE_SSH_DIR:-$REPO_DIR/dotfiles/ssh/.ssh}"
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
OP_VAULT="${TILDE_OP_VAULT:-Private}"
OP_ITEM="${TILDE_OP_ITEM:-tilde age key}"

# Filename -> octal mode. Private keys must be 600 or ssh refuses them.
SECRET_NAMES="arnor:600 arnor_claude:600 arnor_signing:600 arnor.pub:644 arnor_signing.pub:644 known_hosts:644"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

age_recipient() {
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE — run 'secrets.sh op-fetch' or create one with age-keygen"
  age-keygen -y "$AGE_KEY_FILE"
}

###############################################################################
# 1Password                                                                   #
###############################################################################
# There is no way to make the *first* sign-in automatic. Unlocking 1Password
# needs either a human (account password + Secret Key, or Touch ID) or a
# service-account token, and a token on a freshly wiped machine would itself
# have to come from somewhere. What this does instead is make every sign-in
# after the first one hands-free, via the desktop app integration.
# `op whoami` only succeeds when there is a CLI *session* token. Under desktop
# app integration there is none — each command is authorised individually — so
# whoami reports "account is not signed in" while everything else works fine.
# Probe with a real read instead.
op_ready() {
  op account get >/dev/null 2>&1 || op whoami >/dev/null 2>&1
}

op_signin() {
  need op

  # Fully non-interactive, for CI or a scripted rebuild.
  if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    op_ready && return 0
    die "OP_SERVICE_ACCOUNT_TOKEN is set but 1Password rejected it"
  fi

  # Already usable: desktop app integration, or a live session.
  op_ready && return 0

  if [ -d /Applications/1Password.app ]; then
    cat >&2 <<'EOF'
1Password CLI is not connected to the desktop app yet.

  1. Open 1Password and sign in. This needs your account password and Secret
     Key from your Emergency Kit, and cannot be automated — it is the one
     manual step in the whole bootstrap.
  2. Settings -> Developer -> tick "Integrate with 1Password CLI".
  3. Re-run this command. From here on it unlocks with Touch ID.
EOF
    die "1Password CLI not connected"
  fi

  cat >&2 <<'EOF'
Neither the 1Password app nor an active CLI session was found.
Install the app (it is in the Brewfile), sign in, then enable
Settings -> Developer -> "Integrate with 1Password CLI".
EOF
  die "1Password unavailable"
}

op_store() {
  op_signin
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE to store"
  local body
  body="$(cat "$AGE_KEY_FILE")"
  if op item get "$OP_ITEM" --vault "$OP_VAULT" >/dev/null 2>&1; then
    info "Updating existing item '$OP_ITEM' in vault '$OP_VAULT'..."
    op item edit "$OP_ITEM" --vault "$OP_VAULT" "notesPlain=$body" >/dev/null
  else
    info "Creating item '$OP_ITEM' in vault '$OP_VAULT'..."
    op item create --category "Secure Note" --title "$OP_ITEM" \
      --vault "$OP_VAULT" "notesPlain=$body" >/dev/null
  fi
  info "Stored the age key in 1Password. Public key: $(age_recipient)"
}

op_fetch() {
  op_signin
  mkdir -p "$(dirname "$AGE_KEY_FILE")"
  local tmp
  tmp="$(mktemp)"
  if ! op read "op://$OP_VAULT/$OP_ITEM/notesPlain" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    die "could not read '$OP_ITEM' from vault '$OP_VAULT' — run 'secrets.sh op-store' on the old machine first"
  fi
  grep -q "AGE-SECRET-KEY" "$tmp" || { rm -f "$tmp"; die "'$OP_ITEM' does not look like an age key"; }
  install -m 600 "$tmp" "$AGE_KEY_FILE"
  rm -f "$tmp"
  info "Wrote the age key to $AGE_KEY_FILE (public key: $(age_recipient))"
}

###############################################################################
# Passphrase-locked age key                                                   #
###############################################################################
# The age key encrypted under a passphrase that exists only in your head. This
# is what makes a new machine self-sufficient: the blob ships in the repo, so
# one prompt is the entire manual step - no Dropbox, no 1Password, no GUI.
#
# Note this ciphertext is public and therefore attackable offline forever.
# Use a long passphrase; six random words beats a clever short one.
lock_key() {
  need age
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE to lock"
  mkdir -p "$(dirname "$LOCKED_KEY")"
  info "Choose a passphrase for the age key. You will need it on every new"
  info "machine, and it is not recoverable - 1Password stays as the backup."
  age -p -o "$LOCKED_KEY" "$AGE_KEY_FILE" || die "age refused to encrypt the key"
  info "Locked to ${LOCKED_KEY#"$REPO_DIR"/} (public key: $(age_recipient))"
}

unlock_key() {
  need age
  [ -f "$LOCKED_KEY" ] || die "no locked key at $LOCKED_KEY"
  mkdir -p "$(dirname "$AGE_KEY_FILE")"
  local tmp
  tmp="$(mktemp)"
  if ! age -d -o "$tmp" "$LOCKED_KEY"; then
    rm -f "$tmp"
    die "could not decrypt the age key - wrong passphrase?"
  fi
  grep -q "AGE-SECRET-KEY" "$tmp" || { rm -f "$tmp"; die "decrypted blob is not an age key"; }
  install -m 600 "$tmp" "$AGE_KEY_FILE"
  rm -f "$tmp"
  info "Unlocked the age key (public key: $(age_recipient))"
}

# Get a usable age key by whatever means are available, cheapest first.
resolve_key() {
  if [ -f "$AGE_KEY_FILE" ]; then
    info "Using the age key already on this machine."
    return 0
  fi
  if [ -f "$LOCKED_KEY" ]; then
    info "Unlocking the age key from ${LOCKED_KEY#"$REPO_DIR"/}"
    unlock_key
    return 0
  fi
  info "No local or locked key; trying 1Password..."
  op_fetch
}

###############################################################################
# sops                                                                        #
###############################################################################
seal() {
  need sops; need age-keygen
  local recipient plain
  recipient="$(age_recipient)"
  plain="$(mktemp)"
  trap 'rm -f "$plain"' RETURN

  python3 - "$SSH_DIR" "$SECRET_NAMES" > "$plain" <<'PY'
import json, os, sys
ssh_dir, spec = sys.argv[1], sys.argv[2]
out, missing = {}, []
for entry in spec.split():
    name = entry.split(":")[0]
    path = os.path.join(ssh_dir, name)
    if os.path.isfile(path):
        out[name] = open(path, encoding="utf-8").read()
    else:
        missing.append(name)
if missing:
    sys.stderr.write("warning: not found, skipping: %s\n" % " ".join(missing))
if not out:
    sys.stderr.write("error: nothing to seal\n"); sys.exit(1)
json.dump(out, sys.stdout, indent=2, sort_keys=True)
PY

  # Encrypt against the recipient we were given, not whatever .sops.yaml says,
  # so this works for any key/path (tests included). .sops.yaml stays around
  # for driving `sops` by hand against secrets/.
  local cfg
  cfg="$(mktemp)"
  printf 'creation_rules:\n  - path_regex: .*\n    age: %s\n' "$recipient" > "$cfg"

  mkdir -p "$(dirname "$SECRETS_FILE")"
  sops --config "$cfg" --encrypt --age "$recipient" \
       --input-type json --output-type json "$plain" > "$SECRETS_FILE"
  rm -f "$cfg"
  info "Sealed $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "$plain") file(s) to ${SECRETS_FILE#"$REPO_DIR"/}"
}

unseal() {
  need sops
  [ -f "$SECRETS_FILE" ] || die "no sealed secrets at $SECRETS_FILE"
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE — run 'secrets.sh op-fetch' first"

  local plain
  plain="$(mktemp)"
  trap 'rm -f "$plain"' RETURN
  SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" > "$plain" \
    || die "could not decrypt — is this the right age key?"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  python3 - "$SSH_DIR" "$SECRET_NAMES" "$plain" <<'PY'
import json, os, sys
ssh_dir, spec, plain = sys.argv[1], sys.argv[2], sys.argv[3]
modes = dict(e.split(":") for e in spec.split())
data = json.load(open(plain))
for name, content in sorted(data.items()):
    path = os.path.join(ssh_dir, name)
    mode = int(modes.get(name, "600"), 8)
    # Write to a sibling and rename over the target. Opening the target
    # directly fails when it already exists read-only (0400 is a common way to
    # harden an ssh key), which would leave the file stale and the mode wrong.
    tmp = path + ".tilde-tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(content)
    os.chmod(tmp, mode)
    os.replace(tmp, path)
    print("  wrote %s (%s)" % (name, modes.get(name, "600")))
PY
  info "Unsealed into ${SSH_DIR#"$REPO_DIR"/}"
}

status() {
  printf 'age key file   %s\n' "$AGE_KEY_FILE"
  if [ -f "$AGE_KEY_FILE" ]; then
    printf 'age public key %s\n' "$(age-keygen -y "$AGE_KEY_FILE" 2>/dev/null || echo unreadable)"
  else
    printf 'age public key (missing)\n'
  fi
  printf 'locked age key %s\n' "$([ -f "$LOCKED_KEY" ] && echo "${LOCKED_KEY#"$REPO_DIR"/}" || echo '(none)')"
  printf 'sealed file    %s\n' "$([ -f "$SECRETS_FILE" ] && echo "${SECRETS_FILE#"$REPO_DIR"/}" || echo '(none)')"
  printf '1Password      %s\n' "$(op_ready 2>/dev/null && echo 'connected' || echo 'not connected')"
  printf 'vault/item     %s / %s\n' "$OP_VAULT" "$OP_ITEM"
}

case "${1:-}" in
  status)    status ;;
  seal)      seal ;;
  unseal)    unseal ;;
  lock-key)   lock_key ;;
  unlock-key) unlock_key ;;
  op-store)  op_store ;;
  op-fetch)  op_fetch ;;
  bootstrap) resolve_key; unseal ;;
  *)         sed -n "3,16p" "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
