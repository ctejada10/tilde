#!/usr/bin/env bash

# Refresh the Brewfile from what is currently installed, keeping the existing
# category layout and any hand-written modifiers (e.g. `link: false`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE_PATH="${SCRIPT_DIR}/Brewfile"
TEMP_BREWFILE="$(mktemp)"

trap 'rm -f "$TEMP_BREWFILE"' EXIT

echo "Dumping current Homebrew configuration..."
brew bundle dump --file="$TEMP_BREWFILE" --force --quiet

echo "Formatting Brewfile..."
python3 - "$TEMP_BREWFILE" "$BREWFILE_PATH" <<'PY'
import collections, os, re, sys

dumped_path, brewfile_path = sys.argv[1], sys.argv[2]
entry = re.compile(r'^(tap|brew|cask|mas|vscode) "([^"]+)"')

def parse(path):
    out = collections.OrderedDict()
    if not os.path.exists(path):
        return out
    for line in open(path).read().splitlines():
        m = entry.match(line)
        if m:
            out[(m.group(1), m.group(2))] = line
    return out

dumped, existing = parse(dumped_path), parse(brewfile_path)

# Keep the old line when it carries modifiers the dump dropped (link: false,
# trusted: true, args, ...) so hand-tuned entries survive a refresh.
merged = collections.OrderedDict()
for key, line in dumped.items():
    old = existing.get(key)
    merged[key] = old if old and "," in old and "," not in line else line

buckets = collections.defaultdict(list)
for (kind, name), line in merged.items():
    if kind == "tap" and name in ("homebrew/core", "homebrew/cask"):
        continue  # implicit, no longer needs tapping
    buckets["font" if kind == "cask" and name.startswith("font-") else kind].append((name, line))

sections = [("# Taps", "tap"), ("# Binaries", "brew"), ("# Casks", "cask"),
            ("# Fonts", "font"), ("# Mac App Store", "mas"),
            ("# Visual Studio Code extensions", "vscode")]

lines = []
for header, key in sections:
    lines.append(header)
    lines += [l for _, l in sorted(buckets[key], key=lambda p: p[0].lower())]
    lines.append("")

with open(brewfile_path, "w") as fh:
    fh.write("\n".join(lines))

dropped = [f"{k[0]} {k[1]}" for k in existing if k not in merged]
if dropped:
    print("\nRemoved (no longer installed):")
    for d in dropped:
        print(f"  - {d}")
PY

echo "✓ Brewfile updated: $BREWFILE_PATH"
echo ""
echo "Summary:"
brew bundle check --file="$BREWFILE_PATH" || true
