#!/usr/bin/env bash

set -euo pipefail

# Phase 2 runs in a fresh terminal, before ~/.zshrc is linked, so Homebrew is
# not on the PATH yet — and we need `stow` from it.
if ! command -v brew &>/dev/null; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      break
    fi
  done
fi

if ! command -v stow &>/dev/null; then
  echo "Error: stow not found. Run phase 1 first:"
  echo "  curl -fsSL https://raw.githubusercontent.com/ctejada10/tilde/master/setup.sh | bash"
  exit 1
fi

DROPBOX_REPOS="$HOME/Library/CloudStorage/Dropbox/repositories"
SYMLINK="$HOME/Repositories"

# Older Dropbox installs keep the folder at ~/Dropbox instead.
if [ ! -d "$DROPBOX_REPOS" ] && [ -d "$HOME/Dropbox/repositories" ]; then
  DROPBOX_REPOS="$HOME/Dropbox/repositories"
fi

if [ ! -d "$DROPBOX_REPOS/tilde" ]; then
  echo "Error: $DROPBOX_REPOS/tilde not found. Sign into Dropbox and wait for sync to complete."
  exit 1
fi

if [ ! -L "$SYMLINK" ]; then
  if [ -e "$SYMLINK" ]; then
    echo "Error: $SYMLINK exists but is not a symlink. Remove it first."
    exit 1
  fi
  ln -sf "$DROPBOX_REPOS" "$SYMLINK"
  echo "Created symlink: ~/Repositories → $DROPBOX_REPOS"
fi

# ~/src is the Linux-side convention, kept on macOS so paths work either way.
if [ ! -e "$HOME/src" ]; then
  ln -sfn "$DROPBOX_REPOS" "$HOME/src"
  echo "Created symlink: ~/src → $DROPBOX_REPOS"
fi

REPO_DIR="$SYMLINK/tilde"
SCRIPT_DIR="$REPO_DIR/scripts"

# Dropbox does not reliably preserve the executable bit.
chmod +x "$SCRIPT_DIR/ghostty.sh" "$SCRIPT_DIR/.stow" "$SCRIPT_DIR/finish.sh" \
         "$REPO_DIR/dotfiles/tmux/.tmux-window-name.sh" 2>/dev/null || true

###############################################################################
# Secrets                                                                     #
###############################################################################
# If the keys are sealed into git, restore them from there — 1Password holds
# the age key. Falls back to whatever Dropbox synced, which is the old path.
if [ -f "$REPO_DIR/secrets/ssh.enc.json" ]; then
  echo ""
  echo "Restoring SSH keys from the encrypted copy in git..."
  if bash "$SCRIPT_DIR/secrets.sh" bootstrap; then
    echo "Restored from git."
  else
    echo ""
    echo "Could not restore from git — falling back to the copy Dropbox synced."
    echo "Run '$SCRIPT_DIR/secrets.sh bootstrap' by hand once 1Password is set up."
  fi
  echo ""
fi

bash "$SCRIPT_DIR/.stow"

###############################################################################
# SSH key permissions                                                         #
###############################################################################
# ssh refuses to use private keys that are group/world readable, and Dropbox
# does not preserve Unix permissions across machines.
SSH_SRC="$REPO_DIR/dotfiles/ssh/.ssh"
if [ -d "$SSH_SRC" ]; then
  chmod 700 "$SSH_SRC"
  chmod 600 "$SSH_SRC"/arnor "$SSH_SRC"/arnor_claude "$SSH_SRC"/arnor_signing \
            "$SSH_SRC"/config 2>/dev/null || true
  chmod 644 "$SSH_SRC"/*.pub "$SSH_SRC"/allowed_signers "$SSH_SRC"/known_hosts 2>/dev/null || true
  echo "Fixed permissions on $SSH_SRC"
fi

###############################################################################
# Ghostty                                                                     #
###############################################################################
# stow already links ~/.config/ghostty; also link the macOS-native location so
# Ghostty finds the config regardless of which path it prefers.
mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -sfn "$REPO_DIR/dotfiles/ghostty/.config/ghostty/config" \
        "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

###############################################################################
# Fonts                                                                       #
###############################################################################
# Homebrew casks cover the open fonts; MonoLisa is licensed and lives in-repo.
if [ -d "$REPO_DIR/assets/monolisa-font" ]; then
  mkdir -p "$HOME/Library/Fonts"
  cp -n "$REPO_DIR/assets/monolisa-font"/*.ttf "$HOME/Library/Fonts/" 2>/dev/null || true
  echo "Installed MonoLisa fonts to ~/Library/Fonts"
fi

###############################################################################
# Application settings                                                        #
###############################################################################
# This runs here, not in phase 1, because an app has to exist before its
# preferences can be written — phase 1's brew bundle has put them in place by
# now. Anything still missing or currently running is skipped rather than
# clobbered, and the step is safe to run again afterwards.
if [ -f "$REPO_DIR/secrets/app-prefs.enc.json" ]; then
  echo ""
  echo "Restoring application settings..."
  if ! bash "$SCRIPT_DIR/app-prefs.sh" restore; then
    echo "  Could not restore application settings."
    echo "  Run '$SCRIPT_DIR/app-prefs.sh restore' once the apps are installed."
  fi
  echo ""
fi

###############################################################################
# Sanity check                                                                #
###############################################################################
echo ""
echo "Verifying..."
status=0
for link in "$HOME/src" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.gitignore_global" \
            "$HOME/.tmux.conf" "$HOME/.condarc" "$HOME/.config/ghostty/config" \
            "$HOME/.ssh/arnor" \
            "$HOME/Library/Application Support/com.mitchellh.ghostty/config"; do
  if [ -e "$link" ]; then
    echo "  ok      $link"
  else
    echo "  MISSING $link"
    status=1
  fi
done

echo ""
if [ "$status" -eq 0 ]; then
  echo "Done. Dotfiles linked from $REPO_DIR."
  echo ""
  echo "Remaining manual steps:"
  echo "  - Sign in to the App Store, then re-run: brew bundle install --file=$SCRIPT_DIR/Brewfile"
  echo "  - Import Raycast settings from $REPO_DIR/assets/raycast.rayconfig"
  echo "  - Open a new terminal and run: ssh -T git@github.com"
else
  echo "Some links are missing — see above."
  exit 1
fi
