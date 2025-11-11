#!/bin/bash

# Update Brewfile using brew bundle dump and format it to match the current style
# This script dumps the current Homebrew configuration and reorganizes it by category

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE_PATH="${SCRIPT_DIR}/Brewfile"
TEMP_BREWFILE=$(mktemp)

trap "rm -f $TEMP_BREWFILE" EXIT

echo "Dumping current Homebrew configuration..."
brew bundle dump --file="$TEMP_BREWFILE" --force --quiet

echo "Formatting Brewfile..."

# Create a new formatted Brewfile by sorting items into categories
{
    # Extract and organize each section
    echo "# Binaries"
    grep '^brew ' "$TEMP_BREWFILE" | sort | sed 's/^//' 
    echo ""
    
    echo "# Casks"
    grep '^cask ' "$TEMP_BREWFILE" | sort | sed 's/^//'
    echo ""
    
    echo "# Fonts"
    grep '^cask "font-' "$TEMP_BREWFILE" | sort | sed 's/^//'
    echo ""
    
    echo "# Mac App Store"
    grep '^mas ' "$TEMP_BREWFILE" | sort | sed 's/^//'
    echo ""
    
    echo "# Visual Studio Code extensions"
    grep '^vscode ' "$TEMP_BREWFILE" | sort | sed 's/^//'
} > "$BREWFILE_PATH"

# Remove duplicate font entries from the Casks section
{
    echo "# Binaries"
    grep '^brew ' "$TEMP_BREWFILE" | sort
    echo ""
    
    echo "# Casks"
    grep '^cask ' "$TEMP_BREWFILE" | grep -v '^cask "font-' | sort
    echo ""
    
    echo "# Fonts"
    grep '^cask "font-' "$TEMP_BREWFILE" | sort
    echo ""
    
    echo "# Mac App Store"
    grep '^mas ' "$TEMP_BREWFILE" | sort
    echo ""
    
    echo "# Visual Studio Code extensions"
    grep '^vscode ' "$TEMP_BREWFILE" | sort
} > "$BREWFILE_PATH"

echo "✓ Brewfile updated successfully: $BREWFILE_PATH"
echo ""
echo "Summary of changes:"
brew bundle check --file="$BREWFILE_PATH" || true
