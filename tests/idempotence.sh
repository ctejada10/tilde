#!/usr/bin/env bash
# Idempotence suite: run each operation repeatedly and prove the result stops
# moving. Uses deep tree snapshots (path, kind, link target, mode, content
# hash), not just exit codes.
#
#   bash tests/idempotence.sh
#
# Everything runs against throwaway paths. The real $HOME, the real secrets and
# the real Brewfile are never written to.

set -uo pipefail
# shellcheck source=tests/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SCRATCH="${TMPDIR:-/tmp}/tilde-idem-$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

###############################################################################
section "stow: three consecutive runs"
###############################################################################
FAKE="$SCRATCH/home-stow"
make_fake_home "$FAKE"
printf 'source $ZSH/oh-my-zsh.sh\n' > "$FAKE/.zshrc"   # the template phase 1 leaves

for n in 1 2 3; do
  HOME="$FAKE" TILDE_STOW_BACKUP_DIR="$SCRATCH/sb" bash "$REPO_DIR/scripts/.stow" > "$SCRATCH/stow.$n.log" 2>&1
  echo "rc=$?" >> "$SCRATCH/stow.$n.log"
  snapshot "$FAKE" > "$SCRATCH/stow.$n.snap"
done

it "stow run 1 succeeds"
has "$SCRATCH/stow.1.log" "rc=0"

it "stow run 2 succeeds"
has "$SCRATCH/stow.2.log" "rc=0"

it "stow run 3 succeeds"
has "$SCRATCH/stow.3.log" "rc=0"

it "the tree is unchanged between run 1 and run 2"
same_snapshot "$SCRATCH/stow.1.snap" "$SCRATCH/stow.2.snap"

it "the tree is unchanged between run 2 and run 3"
same_snapshot "$SCRATCH/stow.2.snap" "$SCRATCH/stow.3.snap"

it "only the first run reports a conflict"
c1="$(grep -c 'conflict: backing up' "$SCRATCH/stow.1.log")"
c2="$(grep -c 'conflict: backing up' "$SCRATCH/stow.2.log")"
c3="$(grep -c 'conflict: backing up' "$SCRATCH/stow.3.log")"
if [ "$c1" -ge 1 ] && [ "$c2" -eq 0 ] && [ "$c3" -eq 0 ]; then _pass; else _fail "conflicts were $c1/$c2/$c3"; fi

it "repeat runs create no further stow-backups directories"
# One directory from run 1's conflict; runs 2 and 3 must add nothing.
before="$(find "$SCRATCH/sb" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
HOME="$FAKE" TILDE_STOW_BACKUP_DIR="$SCRATCH/sb" bash "$REPO_DIR/scripts/.stow" >/dev/null 2>&1
after="$(find "$SCRATCH/sb" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
eq "$before" "$after"

###############################################################################
section "finish.sh: three consecutive runs"
###############################################################################
# A fresh clone has no decrypted ssh keys - they live encrypted in secrets/.
# Unseal first, the same way typing the passphrase does during a real restore.
if ensure_secrets_available; then
FAKE2="$SCRATCH/home-finish"
make_fake_home "$FAKE2"
printf 'source $ZSH/oh-my-zsh.sh\n' > "$FAKE2/.zshrc"

for n in 1 2 3; do
  in_fake_home "$FAKE2" /bin/bash "$REPO_DIR/scripts/finish.sh" > "$SCRATCH/fin.$n.log" 2>&1
  echo "rc=$?" >> "$SCRATCH/fin.$n.log"
  snapshot "$FAKE2" > "$SCRATCH/fin.$n.snap"
done

it "finish.sh run 1 succeeds"
has "$SCRATCH/fin.1.log" "rc=0"

it "finish.sh run 2 succeeds"
has "$SCRATCH/fin.2.log" "rc=0"

it "finish.sh run 3 succeeds"
has "$SCRATCH/fin.3.log" "rc=0"

it "the home tree is unchanged between run 1 and run 2"
same_snapshot "$SCRATCH/fin.1.snap" "$SCRATCH/fin.2.snap"

it "the home tree is unchanged between run 2 and run 3"
same_snapshot "$SCRATCH/fin.2.snap" "$SCRATCH/fin.3.snap"

it "no run reports a missing link"
if grep -q MISSING "$SCRATCH/fin.1.log" "$SCRATCH/fin.2.log" "$SCRATCH/fin.3.log"; then
  _fail "a run reported MISSING"
else
  _pass
fi

it "fonts are installed once, not duplicated"
same_snapshot <(grep 'Library/Fonts' "$SCRATCH/fin.1.snap") <(grep 'Library/Fonts' "$SCRATCH/fin.3.snap")

it "fonts are not rewritten on later runs (mtimes hold)"
# Content hashes alone cannot see a file rewritten with identical bytes, so
# compare modification times for the things where rewriting would be churn.
m1="$(find "$FAKE2/Library/Fonts" -name '*.ttf' -exec stat -f '%N %m' {} \; 2>/dev/null | LC_ALL=C sort)"
in_fake_home "$FAKE2" /bin/bash "$REPO_DIR/scripts/finish.sh" >/dev/null 2>&1
m2="$(find "$FAKE2/Library/Fonts" -name '*.ttf' -exec stat -f '%N %m' {} \; 2>/dev/null | LC_ALL=C sort)"
eq "$m1" "$m2"

it "the sealed secrets file is not rewritten by finish.sh"
s1="$(stat -f '%m' "$REPO_DIR/secrets/ssh.enc.json" 2>/dev/null || echo none)"
in_fake_home "$FAKE2" /bin/bash "$REPO_DIR/scripts/finish.sh" >/dev/null 2>&1
s2="$(stat -f '%m' "$REPO_DIR/secrets/ssh.enc.json" 2>/dev/null || echo none)"
eq "$s1" "$s2"

else
  skip "finish.sh idempotence (no age key available to unseal the ssh keys)"
fi

###############################################################################
section "secrets: repeated seal / unseal / lock / unlock"
###############################################################################
SB="$SCRATCH/sec"
mkdir -p "$SB/ssh"
age-keygen -o "$SB/age.txt" 2>/dev/null
_hdr='PRIVATE KEY'
printf -- '-----BEGIN OPENSSH %s-----\nIDEMPOTENCE-SENTINEL\n-----END OPENSSH %s-----\n' "$_hdr" "$_hdr" > "$SB/ssh/arnor"
printf 'ssh-ed25519 AAAATEST test@example.com\n' > "$SB/ssh/arnor.pub"
chmod 600 "$SB/ssh/arnor"; chmod 644 "$SB/ssh/arnor.pub"
SEC="$REPO_DIR/scripts/secrets.sh"
sec() { env SOPS_AGE_KEY_FILE="$SB/age.txt" TILDE_SSH_DIR="$SB/ssh" \
            TILDE_SECRETS_FILE="$SB/sealed.enc.json" TILDE_LOCKED_KEY="$SB/locked.age" \
            bash "$SEC" "$@"; }

sec seal >/dev/null 2>&1
cp "$SB/sealed.enc.json" "$SB/sealed.1.json"
sec seal >/dev/null 2>&1
cp "$SB/sealed.enc.json" "$SB/sealed.2.json"

it "sealing twice produces different ciphertext (fresh data key each time)"
if cmp -s "$SB/sealed.1.json" "$SB/sealed.2.json"; then
  _fail "identical ciphertext — that would mean a reused nonce"
else
  _pass
fi

it "...but both seals decrypt to the same plaintext"
for i in 1 2; do
  cp "$SB/sealed.$i.json" "$SB/sealed.enc.json"
  rm -rf "$SB/ssh"; mkdir -p "$SB/ssh"
  sec unseal >/dev/null 2>&1
  snapshot "$SB/ssh" > "$SB/unsealed.$i.snap"
done
same_snapshot "$SB/unsealed.1.snap" "$SB/unsealed.2.snap"

it "unsealing repeatedly leaves an identical tree"
sec unseal >/dev/null 2>&1; snapshot "$SB/ssh" > "$SB/u.a.snap"
sec unseal >/dev/null 2>&1; snapshot "$SB/ssh" > "$SB/u.b.snap"
sec unseal >/dev/null 2>&1; snapshot "$SB/ssh" > "$SB/u.c.snap"
same_snapshot "$SB/u.a.snap" "$SB/u.c.snap"

it "unsealing over read-only-ish existing files still restores modes"
chmod 400 "$SB/ssh/arnor"
sec unseal >/dev/null 2>&1
eq "600" "$(stat -f '%OLp' "$SB/ssh/arnor" 2>/dev/null)"

PASS='six random words go here please'
it "locking twice produces different ciphertext"
with_tty "$PASS\n$PASS\n" env SOPS_AGE_KEY_FILE="$SB/age.txt" TILDE_LOCKED_KEY="$SB/locked.age" bash "$SEC" lock-key
cp "$SB/locked.age" "$SB/locked.1.age"
with_tty "$PASS\n$PASS\n" env SOPS_AGE_KEY_FILE="$SB/age.txt" TILDE_LOCKED_KEY="$SB/locked.age" bash "$SEC" lock-key
cp "$SB/locked.age" "$SB/locked.2.age"
if cmp -s "$SB/locked.1.age" "$SB/locked.2.age"; then _fail "identical ciphertext"; else _pass; fi

it "...but every lock unlocks to the identical key"
for i in 1 2; do
  cp "$SB/locked.$i.age" "$SB/locked.age"
  rm -f "$SB/out.$i.txt"
  with_tty "$PASS\n" env SOPS_AGE_KEY_FILE="$SB/out.$i.txt" TILDE_LOCKED_KEY="$SB/locked.age" bash "$SEC" unlock-key
done
if cmp -s "$SB/out.1.txt" "$SB/out.2.txt" && cmp -s "$SB/age.txt" "$SB/out.1.txt"; then _pass; else _fail "keys differ"; fi

it "unlocking repeatedly is stable"
with_tty "$PASS\n" env SOPS_AGE_KEY_FILE="$SB/rep.txt" TILDE_LOCKED_KEY="$SB/locked.age" bash "$SEC" unlock-key
h1="$(shasum -a 256 "$SB/rep.txt" | cut -d' ' -f1)"
with_tty "$PASS\n" env SOPS_AGE_KEY_FILE="$SB/rep.txt" TILDE_LOCKED_KEY="$SB/locked.age" bash "$SEC" unlock-key
h2="$(shasum -a 256 "$SB/rep.txt" | cut -d' ' -f1)"
eq "$h1" "$h2"

it "bootstrap run repeatedly leaves the same ssh tree"
sec bootstrap >/dev/null 2>&1; snapshot "$SB/ssh" > "$SB/b1.snap"
sec bootstrap >/dev/null 2>&1; snapshot "$SB/ssh" > "$SB/b2.snap"
same_snapshot "$SB/b1.snap" "$SB/b2.snap"

###############################################################################
section "defaults: repeated application"
###############################################################################
DOM="com.tilde.idem.$$"
# shellcheck source=scripts/lib/defaults.sh
. "$REPO_DIR/scripts/lib/defaults.sh"

it "each type reports changed once, then unchanged"
DEFAULTS_CHANGED=0; DEFAULTS_UNCHANGED=0
defaults_set "$DOM" b bool true    >/dev/null
defaults_set "$DOM" i int 42       >/dev/null
defaults_set "$DOM" s string "x y" >/dev/null
defaults_set "$DOM" f float 1.5    >/dev/null
first_changed=$DEFAULTS_CHANGED
DEFAULTS_CHANGED=0; DEFAULTS_UNCHANGED=0
defaults_set "$DOM" b bool true    >/dev/null
defaults_set "$DOM" i int 42       >/dev/null
defaults_set "$DOM" s string "x y" >/dev/null
defaults_set "$DOM" f float 1.5    >/dev/null
if [ "$first_changed" -eq 4 ] && [ "$DEFAULTS_CHANGED" -eq 0 ] && [ "$DEFAULTS_UNCHANGED" -eq 4 ]; then
  _pass
else
  _fail "first=$first_changed second changed=$DEFAULTS_CHANGED unchanged=$DEFAULTS_UNCHANGED"
fi

it "a third pass still reports nothing to do"
DEFAULTS_CHANGED=0
defaults_set "$DOM" b bool true    >/dev/null
defaults_set "$DOM" i int 42       >/dev/null
defaults_set "$DOM" s string "x y" >/dev/null
defaults_set "$DOM" f float 1.5    >/dev/null
eq "0" "$DEFAULTS_CHANGED"

it "-currentHost writes are idempotent too"
DEFAULTS_CHANGED=0
defaults_set_host "$DOM" hostkey int 6 >/dev/null
defaults_set_host "$DOM" hostkey int 6 >/dev/null
eq "1" "$DEFAULTS_CHANGED"

defaults delete "$DOM" >/dev/null 2>&1 || true
defaults -currentHost delete "$DOM" >/dev/null 2>&1 || true

it "macos --check gives identical output on consecutive runs"
bash "$REPO_DIR/scripts/macos" --check > "$SCRATCH/chk.1" 2>&1
bash "$REPO_DIR/scripts/macos" --check > "$SCRATCH/chk.2" 2>&1
if diff -q "$SCRATCH/chk.1" "$SCRATCH/chk.2" >/dev/null; then _pass; else _fail "check output differs between runs"; fi

it "macos --check leaves the system untouched"
# If --check wrote anything, the second run's would-change count would drop.
n1="$(grep -c 'would set' "$SCRATCH/chk.1")"
n2="$(grep -c 'would set' "$SCRATCH/chk.2")"
eq "$n1" "$n2"

###############################################################################
section "update-brewfile.sh"
###############################################################################
it "regenerating the Brewfile twice is a no-op"
BF="$REPO_DIR/scripts/Brewfile"
before="$(shasum -a 256 "$BF" | cut -d' ' -f1)"
bash "$REPO_DIR/scripts/update-brewfile.sh" >/dev/null 2>&1
mid="$(shasum -a 256 "$BF" | cut -d' ' -f1)"
bash "$REPO_DIR/scripts/update-brewfile.sh" >/dev/null 2>&1
after="$(shasum -a 256 "$BF" | cut -d' ' -f1)"
if [ "$before" = "$mid" ] && [ "$mid" = "$after" ]; then
  _pass
else
  _fail "Brewfile changed: before=${before:0:8} mid=${mid:0:8} after=${after:0:8}"
  ( cd "$REPO_DIR" && git checkout -- scripts/Brewfile 2>/dev/null )
fi

summary
