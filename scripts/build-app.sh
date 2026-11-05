#!/bin/zsh
# Builds Emblem.app (release) with the mediaremote-adapter bundled, and installs it to ~/Applications.
set -euo pipefail
ROOT=${0:A:h:h}
cd $ROOT
[[ -d build/adapter/MediaRemoteAdapter.framework ]] || ./scripts/build-adapter.sh
swift build -c release
BIN=$(swift build -c release --show-bin-path)/Emblem
APP=build/Emblem.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources/adapter
cp $BIN $APP/Contents/MacOS/Emblem
cp Resources/Info.plist $APP/Contents/Info.plist
cp Resources/owl_gold.svg Resources/owl_template.svg $APP/Contents/Resources/
cp -R Artists $APP/Contents/Resources/Artists
cp -R build/adapter/MediaRemoteAdapter.framework build/adapter/MediaRemoteAdapterTestClient \
      build/adapter/mediaremote-adapter.pl $APP/Contents/Resources/adapter/
# Sign with the fixed local identity so macOS permissions (e.g. controlling Spotify) survive rebuilds.
# Looks for a self-signed certificate named "Emblem Local Signing" in the Keychain (or "OVOBar Local Signing",
# its name before the app was renamed), and falls back to ad-hoc signing if neither exists.
SIGN="-"
for IDENTITY in "Emblem Local Signing" "OVOBar Local Signing"; do
  if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then SIGN="$IDENTITY"; break; fi
done
codesign --force --sign "$SIGN" $APP/Contents/Resources/adapter/MediaRemoteAdapter.framework
codesign --force --sign "$SIGN" $APP/Contents/Resources/adapter/MediaRemoteAdapterTestClient
codesign --force --sign "$SIGN" --identifier io.github.aboodgitawaida.Emblem $APP
echo "signed with: $SIGN"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  pkill -x Emblem 2>/dev/null || true
  rm -rf ~/Applications/Emblem.app
  cp -R $APP ~/Applications/
  open ~/Applications/Emblem.app
  echo "installed and launched ~/Applications/Emblem.app"
fi
