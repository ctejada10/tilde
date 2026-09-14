#!/usr/bin/env bash
# Test suite for the tilde bootstrap. Run: bash tests/run.sh
#
# Everything here runs against a throwaway $HOME; nothing touches the real one.

set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SCRATCH="${TMPDIR:-/tmp}/tilde-tests-$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

###############################################################################
section "Lint"
###############################################################################
for f in setup.sh scripts/macos scripts/ubuntu scripts/.brew scripts/.stow \
         scripts/.apt scripts/finish.sh scripts/ghostty.sh \
         scripts/update-brewfile.sh scripts/secrets.sh scripts/lib/defaults.sh \
         tests/run.sh tests/lib.sh; do
  [ -f "$REPO_DIR/$f" ] || continue
  it "$f parses"
  ok bash -n "$REPO_DIR/$f"
  it "$f is shellcheck-clean"
  eq "" "$(shellcheck -S warning "$REPO_DIR/$f" 2>&1)"
done

###############################################################################
section "Brewfile"
###############################################################################
BREWFILE="$REPO_DIR/scripts/Brewfile"

it "Brewfile exists"
ok test -f "$BREWFILE"

it "Brewfile has no duplicate entries"
dupes="$(grep -E '^(tap|brew|cask|mas|vscode) ' "$BREWFILE" | sed 's/,.*//' | sort | uniq -d)"
eq "" "$dupes"

it "Brewfile keeps the tailscale link:false modifier"
if grep -q '^brew "tailscale", link: false' "$BREWFILE"; then _pass; else _fail "link: false lost"; fi

it "Brewfile installs the tools the dotfiles assume"
missing=""
for pkg in stow eza bat fzf tmux zoxide; do
  grep -q "^brew \"$pkg\"" "$BREWFILE" || missing="$missing $pkg"
done
eq "" "$missing"

it "Brewfile installs the casks phase 2 depends on"
missing=""
for c in dropbox ghostty; do
  grep -q "^cask \"$c\"" "$BREWFILE" || missing="$missing $c"
done
eq "" "$missing"

it "Brewfile installs miniconda, which .zshrc sources"
if grep -q '^cask "miniconda"' "$BREWFILE"; then _pass; else _fail "miniconda not listed"; fi

###############################################################################
section "macOS script invariants"
###############################################################################
MACOS="$REPO_DIR/scripts/macos"

# Regression: killall Terminal used to kill the script before it finished.
it "does not kill the terminal it runs in"
hasnt "$MACOS" '^[[:space:]]*"Terminal"[[:space:]]*\\'

it "creates the Downloads structure before the killall block"
d="$(grep -n 'Downloads structure' "$MACOS" | head -1 | cut -d: -f1)"
k="$(grep -n 'Kill affected applications' "$MACOS" | head -1 | cut -d: -f1)"
if [ -n "$d" ] && [ -n "$k" ] && [ "$d" -lt "$k" ]; then _pass; else _fail "Downloads($d) not before killall($k)"; fi

it "removes the oh-my-zsh template .zshrc so stow can link ours"
has "$MACOS" 'oh-my-zsh template'

it "guards the screenshot location behind iCloud Drive existing"
has "$MACOS" 'com~apple~CloudDocs" ]; then'

###############################################################################
section "Homebrew bootstrap"
###############################################################################
BREW="$REPO_DIR/scripts/.brew"

it "puts brew on PATH itself after installing"
has "$BREW" 'shellenv'

it "runs the installer non-interactively"
has "$BREW" 'NONINTERACTIVE=1'

it "fails loudly if brew is still missing"
has "$BREW" 'Homebrew installation failed'

###############################################################################
section "stow"
###############################################################################
FAKE="$SCRATCH/home-stow"
make_fake_home "$FAKE"
# Phase 1 leaves an oh-my-zsh template .zshrc behind on a fresh machine.
printf 'source $ZSH/oh-my-zsh.sh\n' > "$FAKE/.zshrc"
STOW_OUT="$SCRATCH/stow.log"
HOME="$FAKE" bash "$REPO_DIR/scripts/.stow" > "$STOW_OUT" 2>&1
stow_rc=$?

it "stows every package without error"
eq "0" "$stow_rc"

it "backs up a conflicting .zshrc instead of aborting"
has "$STOW_OUT" "conflict: backing up"

it "links .zshrc to the repo"
ok test -L "$FAKE/.zshrc"

it "does not fold the whole ~/.config into one package"
# ~/.config must stay a real directory, with only ghostty linked inside it.
if [ -d "$FAKE/.config" ] && [ ! -L "$FAKE/.config" ] && [ -L "$FAKE/.config/ghostty" ]; then
  _pass
else
  _fail "dot-config folded, or ghostty not linked inside it"
fi

it "is idempotent — a second run finds no conflicts"
HOME="$FAKE" bash "$REPO_DIR/scripts/.stow" > "$SCRATCH/stow2.log" 2>&1
eq "0" "$(grep -c 'conflict: backing up' "$SCRATCH/stow2.log")"

###############################################################################
section "finish.sh end to end"
###############################################################################
FAKE2="$SCRATCH/home-finish"
make_fake_home "$FAKE2"
printf 'source $ZSH/oh-my-zsh.sh\n' > "$FAKE2/.zshrc"
FINISH_OUT="$SCRATCH/finish.log"
in_fake_home "$FAKE2" /bin/bash "$REPO_DIR/scripts/finish.sh" > "$FINISH_OUT" 2>&1
finish_rc=$?

it "completes with a clean PATH (no homebrew in the environment)"
eq "0" "$finish_rc"

it "reports no missing links"
hasnt "$FINISH_OUT" 'MISSING'

it "creates both ~/Repositories and ~/src"
if [ -L "$FAKE2/Repositories" ] && [ -L "$FAKE2/src" ]; then _pass; else _fail "symlinks missing"; fi

it "links the ghostty config to a path that resolves"
ok test -e "$FAKE2/Library/Application Support/com.mitchellh.ghostty/config"

it "installs the MonoLisa fonts"
n="$(find "$FAKE2/Library/Fonts" -name 'MonoLisa*.ttf' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n" -gt 0 ]; then _pass; else _fail "no MonoLisa fonts installed"; fi

it "is idempotent"
in_fake_home "$FAKE2" /bin/bash "$REPO_DIR/scripts/finish.sh" > "$SCRATCH/finish2.log" 2>&1
eq "0" "$?"

###############################################################################
section "Idempotent defaults"
###############################################################################
DOM="com.tilde.test.$$"
# shellcheck source=scripts/lib/defaults.sh
. "$REPO_DIR/scripts/lib/defaults.sh"

it "writing a new value counts as changed"
DEFAULTS_CHANGED=0; DEFAULTS_UNCHANGED=0
defaults_set "$DOM" k1 int 7 >/dev/null
eq "1" "$DEFAULTS_CHANGED"

it "writing the same value again counts as unchanged"
DEFAULTS_CHANGED=0; DEFAULTS_UNCHANGED=0
defaults_set "$DOM" k1 int 7 >/dev/null
eq "1" "$DEFAULTS_UNCHANGED"

it "treats true, YES and 1 as the same boolean"
defaults_set "$DOM" k2 bool true >/dev/null
DEFAULTS_UNCHANGED=0
defaults_set "$DOM" k2 bool YES >/dev/null
defaults_set "$DOM" k2 bool 1 >/dev/null
eq "2" "$DEFAULTS_UNCHANGED"

it "compares strings exactly"
defaults_set "$DOM" k3 string "a b" >/dev/null
DEFAULTS_CHANGED=0
defaults_set "$DOM" k3 string "a c" >/dev/null
eq "1" "$DEFAULTS_CHANGED"

it "check mode does not write anything"
( export DEFAULTS_CHECK=1; defaults_set "$DOM" k4 int 99 >/dev/null )
eq "" "$(defaults read "$DOM" k4 2>/dev/null)"

it "run() executes normally but not in check mode"
probe="$SCRATCH/run-probe"
rm -f "$probe"
run touch "$probe"
ran_normally=no; [ -f "$probe" ] && ran_normally=yes
rm -f "$probe"
( export DEFAULTS_CHECK=1; run touch "$probe" >/dev/null )
ran_in_check=no; [ -f "$probe" ] && ran_in_check=yes
rm -f "$probe"
if [ "$ran_normally" = yes ] && [ "$ran_in_check" = no ]; then
  _pass
else
  _fail "normal=$ran_normally check=$ran_in_check"
fi

defaults delete "$DOM" >/dev/null 2>&1 || true

it "macos --check is a genuine dry run (no writes, no sudo prompt)"
MACOS_OUT="$SCRATCH/macos-check.log"
bash "$REPO_DIR/scripts/macos" --check > "$MACOS_OUT" 2>&1
macos_rc=$?
if [ $macos_rc -eq 0 ] && ! grep -qiE "password is required|^  set " "$MACOS_OUT"; then
  _pass
else
  _fail "rc=$macos_rc or it wrote/prompted"
fi

it "macos --check reports a summary"
has "$MACOS_OUT" "dry run:"

it "every defaults write in macos goes through the idempotent wrappers"
stray="$(grep -cE '^(sudo )?defaults (-currentHost )?write ' "$REPO_DIR/scripts/macos" || true)"
eq "0" "$stray"

###############################################################################
section "Secrets (sops + age)"
###############################################################################
SEC="$REPO_DIR/scripts/secrets.sh"

it "secrets.sh reports status without a 1Password session"
ok bash "$SEC" status

it "secrets.sh refuses an unknown subcommand"
no bash "$SEC" definitely-not-a-command

# Everything below uses a throwaway age key and a throwaway ssh dir.
SBOX="$SCRATCH/secrets"
mkdir -p "$SBOX/ssh"
age-keygen -o "$SBOX/age.txt" 2>/dev/null
# Built from parts so this file never contains a literal key header, which
# would trip the leak guard below.
_hdr='PRIVATE KEY'
printf -- '-----BEGIN OPENSSH %s-----\nSENTINEL-MATERIAL\n-----END OPENSSH %s-----\n' "$_hdr" "$_hdr" > "$SBOX/ssh/arnor"
printf 'ssh-ed25519 AAAATEST test@example.com\n' > "$SBOX/ssh/arnor.pub"
chmod 600 "$SBOX/ssh/arnor"; chmod 644 "$SBOX/ssh/arnor.pub"

sec() { env SOPS_AGE_KEY_FILE="$SBOX/age.txt" TILDE_SSH_DIR="$SBOX/ssh"             TILDE_SECRETS_FILE="$SBOX/sealed.enc.json" bash "$SEC" "$@"; }

it "seals the ssh directory"
ok sec seal

it "the sealed file contains no plaintext key material"
hasnt "$SBOX/sealed.enc.json" 'SENTINEL-MATERIAL'

it "the sealed file still names which secrets it holds"
has "$SBOX/sealed.enc.json" '"arnor"'

it "unseals back to identical content"
rm -rf "$SBOX/ssh"
sec unseal >/dev/null 2>&1
has "$SBOX/ssh/arnor" 'SENTINEL-MATERIAL'

it "restores 600 on the private key"
eq "600" "$(stat -f '%OLp' "$SBOX/ssh/arnor" 2>/dev/null)"

it "restores 644 on the public key"
eq "644" "$(stat -f '%OLp' "$SBOX/ssh/arnor.pub" 2>/dev/null)"

it "refuses to unseal with the wrong age key"
age-keygen -o "$SBOX/wrong.txt" 2>/dev/null
no env SOPS_AGE_KEY_FILE="$SBOX/wrong.txt" TILDE_SSH_DIR="$SBOX/ssh"        TILDE_SECRETS_FILE="$SBOX/sealed.enc.json" bash "$SEC" unseal

it "refuses to unseal with no age key at all"
no env SOPS_AGE_KEY_FILE="$SBOX/nonexistent.txt" TILDE_SSH_DIR="$SBOX/ssh"        TILDE_SECRETS_FILE="$SBOX/sealed.enc.json" bash "$SEC" unseal

it ".sops.yaml points at a real age recipient"
has "$REPO_DIR/.sops.yaml" 'age1'

it "no plaintext private key material is tracked in git"
# Pattern assembled from fragments so this file does not match itself.
_k1='BEGIN (OPENSSH|RSA|EC|DSA|PGP) PRIVATE'
_k2='AGE-SECRET'
leaks="$(cd "$REPO_DIR" && git grep -lE "${_k1} KEY|${_k2}-KEY-" -- . 2>/dev/null || true)"
eq "" "$leaks"

it "the sealed secrets file is tracked and encrypted"
if [ -f "$REPO_DIR/secrets/ssh.enc.json" ]; then
  if grep -q 'ENC\[AES256_GCM' "$REPO_DIR/secrets/ssh.enc.json"; then _pass; else _fail "not sops-encrypted"; fi
else
  _pass  # nothing sealed yet is fine
fi

summary
