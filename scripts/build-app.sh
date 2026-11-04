#!/bin/zsh
# Builds OVOBar.app (release) with the mediaremote-adapter bundled, and installs it to ~/Applications.
set -euo pipefail
ROOT=${0:A:h:h}
cd $ROOT
[[ -d build/adapter/MediaRemoteAdapter.framework ]] || ./scripts/build-adapter.sh
swift build -c release
BIN=$(swift build -c release --show-bin-path)/OVOBar
APP=build/OVOBar.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources/adapter
cp $BIN $APP/Contents/MacOS/OVOBar
cp Resources/Info.plist $APP/Contents/Info.plist
cp Resources/owl_gold.svg Resources/owl_template.svg $APP/Contents/Resources/
cp -R build/adapter/MediaRemoteAdapter.framework build/adapter/MediaRemoteAdapterTestClient \
      build/adapter/mediaremote-adapter.pl $APP/Contents/Resources/adapter/
# Sign with the fixed local identity so macOS permissions (e.g. controlling Spotify) survive rebuilds.
# Falls back to ad-hoc signing if the certificate isn't in the Keychain.
IDENTITY="OVOBar Local Signing"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then SIGN="$IDENTITY"; else SIGN="-"; fi
codesign --force --sign "$SIGN" $APP/Contents/Resources/adapter/MediaRemoteAdapter.framework
codesign --force --sign "$SIGN" $APP/Contents/Resources/adapter/MediaRemoteAdapterTestClient
codesign --force --sign "$SIGN" --identifier local.abood.OVOBar $APP
echo "signed with: $SIGN"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  pkill -x OVOBar 2>/dev/null || true
  rm -rf ~/Applications/OVOBar.app
  cp -R $APP ~/Applications/
  open ~/Applications/OVOBar.app
  echo "installed and launched ~/Applications/OVOBar.app"
fi
