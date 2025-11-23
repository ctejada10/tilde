#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/ctejada10/tilde.git"
OS=$(uname)

if [ "$OS" = "Darwin" ]; then
    BASE_DIR="$HOME/Repositories"
    TARGET_DIR="$BASE_DIR/tilde"
    [ -d "$BASE_DIR" ] || mkdir -p "$BASE_DIR"
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Cloning repository to $TARGET_DIR..."
        git clone "$REPO_URL" "$TARGET_DIR"
    else
        echo "Repository already exists at $TARGET_DIR, skipping clone."
    fi
    SCRIPT_DIR="$TARGET_DIR/scripts"
    echo "macOS detected. Installing Xcode command line tools..."
    xcode-select --install
    echo "Executing macOS setup script..."
    bash "$SCRIPT_DIR/macos"
elif [ "$OS" = "Linux" ]; then
    # This script is intended to be run as root on Linux
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
