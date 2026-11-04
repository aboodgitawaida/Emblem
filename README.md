# OVOBar

Personal menu bar replacement for macOS's Now Playing item. The icon morphs into an artist's logo when Spotify plays their track, as lead or featured artist: the OVO owl for Drake, the College Dropout bear for Kanye, the XO for The Weeknd.

## Build & install

```bash
./scripts/build-app.sh --install    # builds, installs to ~/Applications, launches
```

- Built with Swift Package Manager and Command Line Tools (Xcode isn't required).
- `scripts/build-adapter.sh` builds `vendor/mediaremote-adapter` without CMake. It's bundled into `Contents/Resources/adapter`.

## Debug

```bash
.build/release/OVOBar --selftest              # artist matcher cases
.build/release/OVOBar --render-frames <dir>   # morph strip + player PNGs
```

## How it works

- **Spotify** (`SpotifyMonitor`): listens to the `com.spotify.client.PlaybackStateChanged` distributed notification. AppleScript is used only for artwork, the initial state and controls.
- **Everything else** (`MediaRemoteMonitor`): uses the mediaremote-adapter stream via `/usr/bin/perl`. If its self-test fails, only non-Spotify sources are lost.
- **Brands** (`Brand`): each artist's names, Spotify artist ID, logo and player palette. Drake → OVO owl, Kanye → College Dropout bear, The Weeknd → XO.
- **Artist detection** has two checks:
  - `ArtistMatcher`: the artist must be a whole credit in the artist field, or after feat./ft./featuring/with in the title. "Drake Bell" doesn't count. The lead artist wins when several brands are credited.
  - `SpotifyCredits`: Spotify's notification only names the first artist, so the full artist list comes from the track's public embed page (`open.spotify.com/embed/track/<id>`), matched by artist ID.
- **Log**: `~/Library/Logs/OVOBar.log`.
- **Morph** (`StatusIcon`): renders template images frame by frame. The circle shrinks and fades while the logo's lines are revealed along their outlines.
- **Menu**: right-click the icon for Open at Login and Quit.

## Signing

`build-app.sh` signs with the self-signed **OVOBar Local Signing** certificate in your login Keychain, so macOS permissions such as controlling Spotify survive rebuilds. If that certificate is missing, it falls back to ad-hoc signing.

## Layout reference

The player copies the system Now Playing module's measured layout (see `Layout` in `PlayerView.swift`). To re-measure, turn on Accessibility for Claude, then:
- **Find menu bar items:** `tools/axat scan`
- **Open Apple's player:** `tools/axat press <x> <y>`
- **Dump its layout:** `tools/axat ccdump`
- **Dump OVOBar's player:** `tools/axdump ovobar`

Build the tools first, e.g. `swiftc -O tools/axat.swift -o tools/axat`.
