#!/bin/zsh
# Builds MediaRemoteAdapter.framework + test client from vendor/ without CMake.
set -euo pipefail
ROOT=${0:A:h:h}
SRC=$ROOT/vendor/mediaremote-adapter
OUT=$ROOT/build/adapter
rm -rf $OUT && mkdir -p $OUT
FW=$OUT/MediaRemoteAdapter.framework
mkdir -p $FW/Versions/A/Resources
clang -dynamiclib -arch arm64 -fobjc-arc -fvisibility=default \
  -I$SRC/include -I$SRC/src \
  $SRC/src/adapter/*.m $SRC/src/private/MediaRemote.m $SRC/src/utility/*.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -o $FW/Versions/A/MediaRemoteAdapter
cat > $FW/Versions/A/Resources/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
<key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>0.1.0</string>
</dict></plist>
PL
ln -s A $FW/Versions/Current
ln -s Versions/Current/MediaRemoteAdapter $FW/MediaRemoteAdapter
ln -s Versions/Current/Resources $FW/Resources
codesign --force --deep --sign - $FW
clang -arch arm64 -fobjc-arc -I$SRC/src/test $SRC/src/test/main.m $SRC/src/test/NowPlayingTest.m \
  -framework Foundation -framework MediaPlayer -o $OUT/MediaRemoteAdapterTestClient
codesign --force --sign - $OUT/MediaRemoteAdapterTestClient
cp $SRC/bin/mediaremote-adapter.pl $OUT/
echo "adapter built at $OUT"
