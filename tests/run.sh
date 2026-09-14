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
         scripts/update-brewfile.sh scripts/secrets.sh tests/run.sh tests/lib.sh; do
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

summary
