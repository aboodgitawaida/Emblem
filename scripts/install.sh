#!/bin/bash
# Installs the latest Emblem release. Run it with:
#   curl -fsSL https://github.com/aboodgitawaida/Emblem/releases/latest/download/install.sh | bash
set -euo pipefail

URL="https://github.com/aboodgitawaida/Emblem/releases/latest/download/Emblem.zip"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "Emblem is a Mac app."
[[ "$(uname -m)" == "arm64" ]] || fail "Emblem needs a Mac with Apple silicon (M1 or later)."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
(( MAJOR >= 14 )) || fail "Emblem needs macOS 14 or later (this Mac has $(sw_vers -productVersion))."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "Downloading Emblem…"
curl -fL --progress-bar "$URL" -o "$TMP/Emblem.zip" || fail "Download failed. Check your internet connection and try again."
ditto -x -k "$TMP/Emblem.zip" "$TMP"

# /Applications if we can write there, otherwise the user's own Applications folder.
DEST=/Applications
[[ -w "$DEST" ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

pkill -x Emblem 2>/dev/null || true
rm -rf "$DEST/Emblem.app"
ditto "$TMP/Emblem.app" "$DEST/Emblem.app"
# The app isn't notarized by Apple; clearing the download flag stops macOS blocking it.
xattr -dr com.apple.quarantine "$DEST/Emblem.app" 2>/dev/null || true

open "$DEST/Emblem.app"
say "Emblem is installed in $DEST and running in your menu bar."
echo "Play something in Spotify. When macOS asks whether Emblem may control Spotify, click Allow."
