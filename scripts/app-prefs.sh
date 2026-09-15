#!/usr/bin/env bash
#
# Capture and restore the application settings that nothing else syncs.
#
#   app-prefs.sh status    what is captured, and what is installed here
#   app-prefs.sh capture   read settings from this machine into secrets/
#   app-prefs.sh restore   write them back onto a new machine
#
# These are encrypted, because several carry paid licence keys — AlDente's
# paddleLicense, CleanShot's activationKey, Lunar's apiKey — and this repo is
# public. They ride in the same sops/age envelope as the SSH keys, so the same
# passphrase opens them.
#
# Restore deliberately refuses to touch an app that is missing or running:
#   - missing: brew has not installed it yet, and importing a domain for an app
#     that does not exist leaves a preference file its first launch may discard.
#   - running: cfprefsd holds a cached copy per domain and a live app can flush
#     that cache back over the import, silently undoing it.
# Both are skips, not failures. Install or quit the app and run it again.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STORE="${TILDE_APP_PREFS:-$REPO_DIR/secrets/app-prefs.enc.json}"
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

# kind | label | bundle id | target
#   domain -> a defaults domain, exported and imported whole
#   file   -> a single file, path relative to $HOME
#   dir    -> a directory, archived, path relative to $HOME
manifest() {
  printf '%s\n' \
'domain|AdGuard|com.adguard.mac.adguard|com.adguard.mac.adguard' \
'domain|Lunar|fyi.lunar.Lunar|fyi.lunar.Lunar' \
'domain|DEVONthink|com.devon-technologies.think|com.devon-technologies.think' \
'domain|CleanShot X|pl.maketheweb.cleanshotx|pl.maketheweb.cleanshotx' \
'domain|Rectangle Pro|com.knollsoft.Hookshot|com.knollsoft.Hookshot' \
'domain|AltTab|com.lwouis.alt-tab-macos|com.lwouis.alt-tab-macos' \
'domain|AlDente|com.apphousekitchen.aldente-pro|com.apphousekitchen.aldente-pro' \
'domain|IINA|com.colliderli.iina|com.colliderli.iina' \
'domain|Tailscale|io.tailscale.ipn.macsys|io.tailscale.ipn.macsys' \
'domain|Shortery|com.shortery-app.Shortery|com.shortery-app.Shortery' \
'domain|Hidden Bar|com.dwarvesv.minimalbar|com.dwarvesv.minimalbar' \
'domain|Bambu Studio|com.bambulab.bambu-studio|com.bambulab.bambu-studio' \
'domain|Logi Options+|com.logi.optionsplus|com.logi.optionsplus' \
'domain|Visual Studio Code|com.microsoft.VSCode|com.microsoft.VSCode' \
'file|VS Code settings|com.microsoft.VSCode|Library/Application Support/Code/User/settings.json' \
'file|VS Code keybindings|com.microsoft.VSCode|Library/Application Support/Code/User/keybindings.json' \
'file|Bambu Studio config|com.bambulab.bambu-studio|Library/Application Support/BambuStudio/BambuStudio.conf' \
'dir|Bambu Studio profiles|com.bambulab.bambu-studio|Library/Application Support/BambuStudio/user' \
'dir|Bambu Studio printers|com.bambulab.bambu-studio|Library/Application Support/BambuStudio/printers' \
'file|Logi Options+ settings|com.logi.optionsplus|Library/Application Support/logioptionsplus/settings.db' \
'file|Logi Options+ config|com.logi.optionsplus|Library/Application Support/logioptionsplus/config.json'
}

app_path() { mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | grep -m1 '\.app$' || true; }

app_running() {
  local bundle="$1" app
  app="$(app_path "$bundle")"
  [ -n "$app" ] || return 1
  pgrep -f "$(basename "$app" .app)" >/dev/null 2>&1
}

###############################################################################
capture() {
  need sops; need age-keygen
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE"
  local recipient work plain cfg
  recipient="$(age-keygen -y "$AGE_KEY_FILE")"
  work="$(mktemp -d)"; plain="$(mktemp)"; cfg="$(mktemp)"
  trap 'rm -rf "$work" "$plain" "$cfg"' RETURN

  local n=0 skipped=0
  : > "$work/index"
  while IFS='|' read -r kind label bundle target; do
    [ -n "${kind:-}" ] || continue
    case "$kind" in
      domain)
        if defaults export "$target" "$work/blob" 2>/dev/null && [ -s "$work/blob" ]; then
          printf '%s\t%s\t%s\t%s\n' "$kind" "$label" "$target" "$(base64 < "$work/blob" | tr -d '\n')" >> "$work/index"
          info "  captured  $label ($(wc -c < "$work/blob" | tr -d ' ') bytes)"
          n=$((n+1))
        else
          info "  skipped   $label — no preferences to read"; skipped=$((skipped+1))
        fi ;;
      file)
        if [ -f "$HOME/$target" ]; then
          printf '%s\t%s\t%s\t%s\n' "$kind" "$label" "$target" "$(base64 < "$HOME/$target" | tr -d '\n')" >> "$work/index"
          info "  captured  $label"
          n=$((n+1))
        else
          info "  skipped   $label — not present"; skipped=$((skipped+1))
        fi ;;
      dir)
        if [ -d "$HOME/$target" ]; then
          tar -czf "$work/blob" -C "$HOME" "$target" 2>/dev/null
          printf '%s\t%s\t%s\t%s\n' "$kind" "$label" "$target" "$(base64 < "$work/blob" | tr -d '\n')" >> "$work/index"
          info "  captured  $label ($(du -sh "$HOME/$target" 2>/dev/null | cut -f1))"
          n=$((n+1))
        else
          info "  skipped   $label — not present"; skipped=$((skipped+1))
        fi ;;
    esac
  done <<EOF
$(manifest)
EOF

  python3 - "$work/index" > "$plain" <<'PY'
import json, sys
out = {}
for line in open(sys.argv[1], encoding="utf-8"):
    kind, label, target, blob = line.rstrip("\n").split("\t", 3)
    out[f"{kind}:{target}"] = {"label": label, "data": blob}
json.dump(out, sys.stdout, indent=2, sort_keys=True)
PY
  printf 'creation_rules:\n  - path_regex: .*\n    age: %s\n' "$recipient" > "$cfg"
  mkdir -p "$(dirname "$STORE")"
  sops --config "$cfg" --encrypt --age "$recipient" \
       --input-type json --output-type json "$plain" > "$STORE"
  info ""
  info "Sealed $n item(s) to ${STORE#"$REPO_DIR"/}${skipped:+ ($skipped skipped)}"
}

###############################################################################
restore() {
  need sops
  [ -f "$STORE" ] || die "nothing captured at $STORE"
  [ -f "$AGE_KEY_FILE" ] || die "no age key at $AGE_KEY_FILE — run 'secrets.sh bootstrap' first"

  local plain work
  plain="$(mktemp)"; work="$(mktemp -d)"
  trap 'rm -rf "$plain" "$work"' RETURN
  SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$STORE" > "$plain" \
    || die "could not decrypt $STORE"

  local done=0 missing=0 busy=0
  while IFS='|' read -r kind label bundle target; do
    [ -n "${kind:-}" ] || continue
    if ! python3 - "$plain" "$kind:$target" "$work/blob" <<'PY'
import base64, json, sys
data = json.load(open(sys.argv[1]))
entry = data.get(sys.argv[2])
if not entry:
    sys.exit(1)
open(sys.argv[3], "wb").write(base64.b64decode(entry["data"]))
PY
    then
      continue   # not in the capture
    fi

    # The app has to exist, or its first launch may discard what we write.
    if [ -z "$(app_path "$bundle")" ]; then
      info "  skipped   $label — app not installed yet"
      missing=$((missing+1)); continue
    fi
    # And it must not be running, or cfprefsd flushes its cache over us.
    if app_running "$bundle"; then
      info "  skipped   $label — quit the app and run this again"
      busy=$((busy+1)); continue
    fi

    case "$kind" in
      domain)
        defaults import "$target" "$work/blob" && info "  restored  $label" && done=$((done+1)) ;;
      file)
        mkdir -p "$(dirname "$HOME/$target")"
        cp "$work/blob" "$HOME/$target" && info "  restored  $label" && done=$((done+1)) ;;
      dir)
        mkdir -p "$(dirname "$HOME/$target")"
        tar -xzf "$work/blob" -C "$HOME" && info "  restored  $label" && done=$((done+1)) ;;
    esac
  done <<EOF
$(manifest)
EOF

  killall cfprefsd 2>/dev/null || true
  info ""
  info "Restored $done item(s)."
  [ "$missing" -gt 0 ] && info "$missing skipped because the app is not installed — install it, then re-run."
  [ "$busy" -gt 0 ] && info "$busy skipped because the app is running — quit it, then re-run."
  return 0
}

###############################################################################
status() {
  printf 'store        %s\n' "$([ -f "$STORE" ] && echo "${STORE#"$REPO_DIR"/}" || echo '(nothing captured)')"
  printf 'age key      %s\n\n' "$([ -f "$AGE_KEY_FILE" ] && echo present || echo missing)"
  printf '%-24s %-10s %s\n' "ITEM" "INSTALLED" "KIND"
  while IFS='|' read -r kind label bundle target; do
    [ -n "${kind:-}" ] || continue
    printf '%-24s %-10s %s\n' "${label:0:23}" \
      "$([ -n "$(app_path "$bundle")" ] && echo yes || echo no)" "$kind"
  done <<EOF
$(manifest)
EOF
}

case "${1:-}" in
  capture) capture ;;
  restore) restore ;;
  status)  status ;;
  *) sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
