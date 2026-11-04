# OVOBar: context for Claude

A personal macOS menu bar app that replaces the system Now Playing item. It works like the system item, except it morphs into the OVO owl while Spotify plays a Drake track (lead or featured). It's for the owner's own Mac only and is never shared. The repo is private: the OVO owl and name are OVO's trademarks.

## Build and run

- **Build and install:** `./scripts/build-app.sh --install` builds with SwiftPM, installs to `~/Applications/OVOBar.app` and relaunches it. Xcode isn't installed (Command Line Tools only), so there's no `xcodebuild`.
- **Signing:** the script signs with the self-signed **OVOBar Local Signing** identity in the login Keychain, so macOS permissions (Automation for Spotify) survive rebuilds. Don't switch to ad-hoc signing.
- **Log:** `~/Library/Logs/OVOBar.log`.
- **Checks:** `.build/release/OVOBar --selftest` runs the Drake matcher cases. `--render-frames <dir>` writes the morph strip and player previews.
- **Login item:** registered via SMAppService on first launch.

## Owner's preferences

- **Match Apple exactly:** the player must match the system Now Playing module pixel for pixel. Verify against Apple's live player rather than guessing, and give numbers.
- **One source:** show one player at a time, never the stacked multi-source view Apple sometimes shows.
- **Check System Settings changes:** ask the owner before changing System Settings.

## Measuring Apple's player

Read the live system module through Accessibility. The tools are in `tools/` (build with `swiftc -O tools/axat.swift -o tools/axat`). Accessibility must be on for the lowercase `claude` helper (the Claude Code binary), not just the Claude app.

- `tools/axat scan`: menu bar items and their frames. Apple's items belong to `com.apple.MenuBarAgent`.
- `tools/axat press <x> <y>`: opens or closes Apple's player. It's a toggle, so check `tools/axat agent` first.
- `tools/axat ccdump`: dumps Apple's open player: frames, fonts, values.
- `tools/axat track <secs> [bundle-id]`: samples text positions over time, used for the marquee timing.
- `tools/axdump ovobar`: dumps OVOBar's own panel for comparison.

Screenshots the owner pastes are usually scaled. Calibrate pixel measurements against a known size first: the cover is 112pt, the battery icon 26pt.

## Measured values (macOS 27, 33pt notch menu bar)

- **Panel:** 308 × 140pt, 1pt below the menu bar, left edge at the item's slot. The `Layout` enum in `PlayerView.swift` holds every coordinate.
- **Text:** title 13pt semibold, artist line 11pt regular, times 10pt regular. Times use `00:00`, or `00:00:00` once past an hour, and a real minus sign (U+2212).
- **Buttons:** 26pt hit areas, 56pt apart. ⏮ ⏭ symbols at 16pt, ⏯ at 23.5pt.
- **Progress bar:** 4pt track. The knob is a ~15.5 × 11.5pt capsule and only shows on hover.
- **Scrolling text:** 3s rest, 30pt/s, 21pt gap. It restarts on every open, and the left edge only fades while moving.
- **Audio meter:** 5 bars, 1.5pt wide, 1.5pt apart, up to ~11pt tall, dim. Dots when paused.
- **Browser video:**
  - **Thumbnail:** non-square artwork is letterboxed, with the app icon in a 19pt frame overhanging the square's corner by 3pt.
  - **Buttons:** `15.arrow.trianglehead.counterclockwise` / `.clockwise` replace previous/next.
  - **Artist line:** "Artist – " when the source sends an empty album.
- **Menu bar pill:**
  - **Size:** the "open" pill is 37 × 23pt, ~15.5% white, centered on the icon. It's drawn by `PillWindow`, a click-through window behind the item.
  - **Timing:** it appears instantly on mouse release, because macOS draws its own ~57pt press pill while the mouse is held.
  - **Item width:** the status item uses its natural variable length. A fixed length makes macOS's press pill much wider.
- **Menu bar owl:** 16.5pt tall. Only the body outline is thickened (0.4pt); the face is left crisp.

## Behaviour notes

- **Spotify:**
  - **Updates:** the `com.spotify.client.PlaybackStateChanged` distributed notification, observed with `.deliverImmediately`. Without it, a menu bar app gets nothing.
  - **Display:** the player shows the notification's main artist only, as Apple does.
- **Drake detection:**
  - **Name and title check:** `DrakeMatcher` checks the artist field and "feat./ft./with" in the title, by whole artist name. "Drake Bell" doesn't count.
  - **Full credits:** `SpotifyCredits` reads the track's public embed page and matches Drake's artist ID, `spotify:artist:3TVXtAsR1Inumwj472S9r4`.
- **Other sources:** `mediaremote-adapter` (git submodule) via `/usr/bin/perl`. If it breaks, only non-Spotify sources are lost.
- **Panel:**
  - **Window:** a borderless panel with `hidesOnDeactivate = false`.
  - **Icon clicks:** handled by a local mouse-down monitor, so the button's own tracking doesn't fight the pill.
- **Drake moment:** when a Drake track starts, a gold shimmer sweeps across the player once and the cover's glow swells.

## Open ideas, not done

- **Hide when idle:** hide the icon until something has played, as Apple does.
- **Other menu bars:** scale the pill and positions for 24pt menu bars on external displays and non-notch Macs.
- **Light mode:** check the light menu bar and the OVO gold in light mode.
- **Unchecked Apple behaviour:** button hover and press states, the progress bar while dragging, and the 2pt longer bar on hour-long videos.
- **Queue end:** the last song in the queue finishing is untested.
