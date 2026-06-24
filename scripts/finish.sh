#!/usr/bin/env bash

set -euo pipefail

DROPBOX_REPOS="$HOME/Library/CloudStorage/Dropbox/repositories"
SYMLINK="$HOME/Repositories"

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

REPO_DIR="$SYMLINK/tilde"
SCRIPT_DIR="$REPO_DIR/scripts"

bash "$SCRIPT_DIR/.stow"

mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -sf "$REPO_DIR/dotfiles/ghostty/config" \
       "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "Done. Dotfiles linked from $REPO_DIR."
