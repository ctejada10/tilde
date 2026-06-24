#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/ctejada10/tilde.git"
OS=$(uname)

install_xcode_clt() {
  if xcode-select -p &>/dev/null 2>&1; then
    echo "Xcode Command Line Tools already installed."
    return 0
  fi
  echo "Installing Xcode Command Line Tools (click Install in the dialog)..."
  xcode-select --install
  until xcode-select -p &>/dev/null 2>&1; do
    sleep 5
  done
  echo "Xcode Command Line Tools installed."
}

if [ "$OS" = "Darwin" ]; then
  TMP_DIR="/tmp/tilde-setup-$$"
  mkdir -p "$TMP_DIR"

  install_xcode_clt

  echo "Cloning repository to $TMP_DIR..."
  git clone "$REPO_URL" "$TMP_DIR"

  echo "Executing macOS setup script..."
  bash "$TMP_DIR/scripts/macos"

  echo ""
  echo "Homebrew and macOS settings are done."
  echo "Sign into Dropbox and wait for it to sync, then run:"
  echo "  bash ~/Library/CloudStorage/Dropbox/repositories/tilde/scripts/finish.sh"

elif [ "$OS" = "Linux" ]; then
  TMP_DIR="/tmp/tilde-setup-$$"
  mkdir -p "$TMP_DIR"
  echo "Cloning repository to $TMP_DIR..."
  git clone "$REPO_URL" "$TMP_DIR"
  chmod -R a+rX "$TMP_DIR"
  echo "Running Ubuntu setup script as root..."
  bash "$TMP_DIR/scripts/ubuntu" "$TMP_DIR"

else
  echo "OS not recognized: $OS. Exiting."
  exit 1
fi
