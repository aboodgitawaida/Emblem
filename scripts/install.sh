#!/bin/bash
# Installs (or updates) Emblem. Run it with:
#   curl -fsSL https://github.com/aboodgitawaida/Emblem/releases/latest/download/install.sh | bash
# To remove Emblem:
#   curl -fsSL https://github.com/aboodgitawaida/Emblem/releases/latest/download/install.sh | bash -s uninstall
set -euo pipefail

URL="https://github.com/aboodgitawaida/Emblem/releases/latest/download/Emblem.zip"
BUNDLE_ID="io.github.aboodgitawaida.Emblem"

step() { printf '\033[1m→ %s\033[0m\n' "$*"; }
done_() { printf '\033[32m✓ %s\033[0m\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Every copy Emblem could be in, including the old OVOBar name.
COPIES=(/Applications/Emblem.app "$HOME/Applications/Emblem.app" /Applications/OVOBar.app "$HOME/Applications/OVOBar.app")

quit_running() {
  pkill -x Emblem 2>/dev/null || true
  pkill -x OVOBar 2>/dev/null || true
  sleep 0.5
}

remove_copies() {
  for app in "${COPIES[@]}"; do
    [[ -e "$app" ]] && rm -rf "$app" 2>/dev/null || true
  done
}

uninstall() {
  step "Removing Emblem…"
  quit_running
  remove_copies
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  rm -f "$HOME/Library/Logs/Emblem.log"
  done_ "Emblem is removed."
  echo "  If it's still listed in System Settings → General → Login Items, select it and click −."
}

install() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "Emblem is a Mac app."
  [[ "$(uname -m)" == "arm64" ]] || fail "Emblem needs a Mac with Apple silicon (M1 or later)."
  local major
  major=$(sw_vers -productVersion | cut -d. -f1)
  (( major >= 14 )) || fail "Emblem needs macOS 14 or later. This Mac has $(sw_vers -productVersion)."

  local action="Installing"
  for app in "${COPIES[@]}"; do [[ -e "$app" ]] && action="Updating"; done || true

  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  step "Downloading Emblem…"
  curl -fsSL "$URL" -o "$TMP/Emblem.zip" || fail "The download failed. Check your internet connection and try again."
  ditto -x -k "$TMP/Emblem.zip" "$TMP" || fail "The download was damaged. Try again."
  local version
  version=$(defaults read "$TMP/Emblem.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "")

  step "$action Emblem${version:+ $version}…"
  # /Applications if this account can write there, otherwise the account's own Applications folder.
  local dest=/Applications
  [[ -w "$dest" ]] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
  quit_running
  remove_copies   # so there's only ever one Emblem
  ditto "$TMP/Emblem.app" "$dest/Emblem.app"
  # Emblem isn't notarized by Apple. Clearing the download flag stops macOS blocking it.
  xattr -dr com.apple.quarantine "$dest/Emblem.app" 2>/dev/null || true

  step "Opening Emblem…"
  open "$dest/Emblem.app"

  echo
  done_ "Emblem${version:+ $version} is installed and running in your menu bar. It starts by itself when you log in."
  if [[ -d /Applications/Spotify.app || -d "$HOME/Applications/Spotify.app" ]]; then
    echo "  Play a song in Spotify. When macOS asks whether Emblem may control Spotify, click Allow."
  else
    echo "  Spotify isn't installed on this Mac. Emblem's logos only appear for Spotify, so get it from spotify.com/download."
  fi
}

# Everything runs from here, so a half-downloaded script never runs halfway.
case "${1:-install}" in
  uninstall) uninstall ;;
  *) install ;;
esac
