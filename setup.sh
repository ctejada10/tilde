#!/usr/bin/env bash

REPO_URL="https://github.com/ctejada10/tilde.git"

# Detect operating system early to determine clone location
OS=$(uname)

if [ "$OS" = "Darwin" ]; then
    BASE_DIR="$HOME/Repositories"
elif [ "$OS" = "Linux" ]; then
    BASE_DIR="$HOME/src"
else
    echo "OS not recognized: $OS. Exiting."
    exit 1
fi

TARGET_DIR="$BASE_DIR/tilde"

# Ensure base dir exists
[ -d "$BASE_DIR" ] || mkdir -p "$BASE_DIR"

# Clone repository if not already cloned
if [ ! -d "$TARGET_DIR" ]; then
    echo "Cloning repository to $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo "Repository already exists at $TARGET_DIR, skipping clone."
fi

SCRIPT_DIR="$TARGET_DIR/scripts"

if [ "$OS" = "Darwin" ]; then
    echo "macOS detected. Installing Xcode command line tools..."
    xcode-select --install
    echo "Executing macOS setup script..."
    bash "$SCRIPT_DIR/macos"
elif [ "$OS" = "Linux" ]; then
    echo "Linux detected. Executing Ubuntu setup script..."
    (cd "$SCRIPT_DIR" && bash ./ubuntu)
fi
