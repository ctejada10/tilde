#!/usr/bin/env bash
REPO_URL="https://github.com/ctejada10/tilde.git"
TARGET_DIR="$HOME/Repositories/tilde"

# Ensure ~/Repositories exists
[ -d "$HOME/Repositories" ] || mkdir -p "$HOME/Repositories"

# Clone repository if not already cloned
if [ ! -d "$TARGET_DIR" ]; then
    echo "Cloning repository to $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo "Repository already exists at $TARGET_DIR, skipping clone."
fi

# Detect operating system
OS=$(uname)
SCRIPT_DIR="$TARGET_DIR/scripts"

if [ "$OS" = "Darwin" ]; then
    echo "macOS detected. Installing Xcode command line tools..."
    xcode-select --install
    echo "Executing macOS setup script..."
    bash "$SCRIPT_DIR/macos"
elif [ "$OS" = "Linux" ]; then
    echo "Linux detected. Executing Ubuntu setup script..."
    # Ensure the ubuntu script runs from the scripts directory so relative sources work
    (cd "$SCRIPT_DIR" && bash ./ubuntu)
else
    echo "OS not recognized: $OS. Exiting."
    exit 1
fi
