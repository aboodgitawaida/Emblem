# Developing Emblem

Everything you need to build, debug and extend Emblem. For installing it, see the [README](../README.md).

**Built with:** Swift, SwiftUI and AppKit, Swift Package Manager (no Xcode), AppleScript and distributed notifications for Spotify, a vendored MediaRemote adapter for other sources.

## Build from source

```bash
./scripts/build-app.sh --install    # builds, installs to ~/Applications, launches
```

- Built with Swift Package Manager and Command Line Tools (Xcode isn't required).
- `scripts/build-adapter.sh` builds `vendor/mediaremote-adapter` without CMake. It's bundled into `Contents/Resources/adapter`.

## Adding an artist

Each artist is a folder in `Artists/` with an `artist.json` and a `logo.svg`, so adding one needs no code. You can
also drop folders into `~/Library/Application Support/Emblem/Artists/` without rebuilding. See
[ADDING_ARTISTS.md](../ADDING_ARTISTS.md).

## Debug

```bash
.build/release/Emblem --selftest              # artist matcher cases
.build/release/Emblem --check-artists         # loads every artist folder and explains any problem
.build/release/Emblem --render-frames <dir>   # morph strip + player PNGs
.build/release/Emblem --fit-logo <svg>        # crops a logo's viewBox tight
tools/compare                                 # Emblem's player vs the system's, element by element
```

## How it works

- **Spotify** (`SpotifyMonitor`): listens to the `com.spotify.client.PlaybackStateChanged` distributed notification. AppleScript is used only for artwork, the initial state and controls.
- **Everything else** (`MediaRemoteMonitor`): uses the mediaremote-adapter stream via `/usr/bin/perl`. This includes Apple Music and browser players such as YouTube Music, SoundCloud, and TIDAL; Apple Music uses the same standard previous/play/next controls as the system Now Playing item, while browser video uses 15-second skip controls. If the adapter self-test fails, only non-Spotify sources are lost.
- **Artists** (`Artists/<id>/`): each artist is a folder with `artist.json` (names, Spotify artist ID, sizes, fallback palette) and `logo.svg`, loaded at launch by `ArtistLibrary`. The player's colours come from the playing album's art (`ArtworkPalette`). Drake → OVO owl, Kanye → College Dropout bear, The Weeknd → XO, Travis Scott → Cactus Jack face, Tyler, the Creator → GOLF le FLEUR* flower, J. Cole → Born Sinner crown, MF DOOM → his mask, Wu-Tang Clan → the W, 21 Savage → the dagger, Billie Eilish → the Blohsh figure, Lil Peep → the broken heart, Kendrick Lamar → a crown of thorns (drawn for Emblem), Lil Yachty → the Concrete Boys stick figure.
- **Artist detection** has two checks:
  - `ArtistMatcher`: the artist must be a whole credit in the artist field, or after feat./ft./featuring/with in the title. "Drake Bell" doesn't count. The lead artist wins when several brands are credited.
  - `SpotifyCredits`: Spotify's notification only names the first artist, so the full artist list comes from the track's public embed page (`open.spotify.com/embed/track/<id>`), matched by artist ID.
- **Log**: `~/Library/Logs/Emblem.log`.
- **Morph** (`StatusIcon`): renders template images frame by frame. The circle shrinks and fades while the logo's lines are revealed along their outlines.
- **Menu**: right-click the icon for Open at Login and Quit.

## Signing

`build-app.sh` signs with the self-signed **Emblem Local Signing** certificate in your login Keychain, so macOS permissions such as controlling Spotify survive rebuilds. To make one, open Keychain Access, choose Certificate Assistant → Create a Certificate, pick the "Code Signing" type and name it exactly that. If no such certificate exists, it falls back to ad-hoc signing, and macOS will ask for Spotify access again after every rebuild.

## Layout reference

The player copies the system Now Playing module's measured layout (see `Layout` in `PlayerView.swift`). To re-measure, give your terminal Accessibility access (System Settings → Privacy & Security), then:
- **Find menu bar items:** `tools/axat scan`
- **Open Apple's player:** `tools/axat press <x> <y>`
- **Dump its layout:** `tools/axat ccdump`
- **Dump Emblem's player:** `tools/axdump emblem`

Build the tools first, e.g. `swiftc -O tools/axat.swift -o tools/axat`.

## Requirements

- macOS 14 or later. Some effects need newer systems: the flowing background needs macOS 15, and the glass panel needs macOS 26. Older systems fall back to a flat panel.
- Command Line Tools only (no Xcode). Clone with `git clone --recursive` so the `mediaremote-adapter` submodule comes along.
- Spotify. The first time you play a track, macOS asks whether Emblem may control Spotify; allow it.

## Brand images

The banner (its row of logos comes from the artist folders, its players from `docs/player-*.png`) and the app icon:

```bash
node tools/brand/render.mjs        # banner and build/icon-1024.png (needs Playwright and the Inter font)
python3 tools/brand/make-icns.py   # build/icon-1024.png → Resources/AppIcon.icns (needs Pillow)
```

## Player screenshots

The README's `docs/player-*.png` are the app's own renders with real album art. `tools/brand/covers.py` lists the songs and downloads their covers from the iTunes catalogue; on a Mac:

```bash
swift build -c release
specs=(); while IFS= read -r l; do specs+=("$l"); done < <(python3 tools/brand/covers.py /tmp/covers)
.build/release/Emblem --render-covers /tmp/players "${specs[@]}"   # writes cover_<name>.png
```

Copy each `cover_<name>.png` to `docs/player-<name>.png`.

## Releases

Push a version tag (`git tag v1.2.0 && git push origin v1.2.0`) or use **Run workflow** on the Release action. `.github/workflows/release.yml` builds on macOS 26 and publishes `install.sh` and `Emblem.zip`.
