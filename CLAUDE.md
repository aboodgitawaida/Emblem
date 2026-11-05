# Emblem: notes for contributors and coding agents

A personal macOS menu bar app that replaces the system Now Playing item. It works like the system item, except it morphs into an artist's logo while Spotify plays their track (lead or featured): the OVO owl for Drake, the College Dropout bear for Kanye, the XO for The Weeknd, the Cactus Jack face for Travis Scott, the GOLF le FLEUR* flower for Tyler, the Creator, the Born Sinner crown for J. Cole. It was called OVOBar before it was renamed Emblem. The logos and names belong to their owners (OVO, the artists and their labels); see the disclaimer in README.md.

## Build and run

- **Build and install:** `./scripts/build-app.sh --install` builds with SwiftPM, installs to `~/Applications/Emblem.app` and relaunches it. Xcode isn't installed (Command Line Tools only), so there's no `xcodebuild`.
- **Signing:** the script signs with a self-signed certificate in the login Keychain, so macOS permissions (Automation for Spotify) survive rebuilds. It looks for **Emblem Local Signing**, then **OVOBar Local Signing** (the name from before the rename; still accepted). Don't switch to ad-hoc signing.
- **Log:** `~/Library/Logs/Emblem.log`.
- **Checks:** `.build/release/Emblem --selftest` runs the artist matcher cases. `--render-frames <dir>` writes the morph strip and player previews.
- **Login item:** registered via SMAppService on first launch.

## Design rules

- **Match Apple exactly:** the player must match the system Now Playing module pixel for pixel. Verify against Apple's live player rather than guessing, and give numbers.
- **One source:** show one player at a time, never the stacked multi-source view Apple sometimes shows.
- **System Settings:** ask before changing System Settings.

## Measuring Apple's player

Read the live system module through Accessibility. The tools are in `tools/` (build with `swiftc -O tools/axat.swift -o tools/axat`). Accessibility must be on for whichever process runs the tools (your terminal, or a coding agent's binary).

- `tools/axat scan`: menu bar items and their frames. Apple's items belong to `com.apple.MenuBarAgent`.
- `tools/axat press <x> <y>`: opens or closes Apple's player. It's a toggle, so check `tools/axat agent` first.
- `tools/axat ccdump`: dumps Apple's open player: frames, fonts, values.
- `tools/axat track <secs> [bundle-id]`: samples text positions over time, used for the marquee timing.
- `tools/axdump emblem`: dumps Emblem's own panel for comparison.

Pasted screenshots are usually scaled. Calibrate pixel measurements against a known size first: the cover is 112pt, the battery icon 26pt.

## Measured values (macOS 27, 33pt notch menu bar)

- **Panel:** 308 × 140pt, 1pt below the menu bar, left edge at the item's slot. The `Layout` enum in `PlayerView.swift` holds every coordinate.
- **Text:** title 13pt semibold, artist line 11pt regular, times 10pt regular. Times use `00:00`, or `00:00:00` once past an hour, and a real minus sign (U+2212).
- **Buttons:** 26pt hit areas, 56pt apart. ⏮ ⏭ symbols at 16pt, ⏯ at 23.5pt.
- **Progress bar:** 4pt track. The knob is a ~15.5 × 11.5pt capsule and only shows on hover or while dragging. It fades in and out in place (it doesn't grow). The system bar is a custom control (an `AXSlider` with no value-indicator child), so there's no stock slider to reuse.
- **Progress fill:** progress maps onto the knob's path, not the whole bar: the fill ends at the knob's centre, 8pt + fraction × (width − 16pt). At 0 there's no fill, and over the first ~2% it grows at fraction × width × 3.64 until it meets that line (`Scrubber.fillEnd`). Measured at 2× on a 154pt bar at 14 song positions (Spotify `set player position`, then the slider's `AXValue` and a screenshot); the formula is within 0.5pt of every one. A plain fraction × width was up to 8pt off.
- **Scrolling text:** 3s rest, 30pt/s, 21pt gap. It restarts on every open, and the left edge only fades while moving.
- **Audio meter:** 5 bars, 1.5pt wide, 1.5pt apart, up to ~11pt tall, dim. Dots when paused.
- **Browser video:**
  - **Thumbnail:** non-square artwork is letterboxed, with the app icon in a 19pt frame overhanging the square's corner by 3pt.
  - **Buttons:** `15.arrow.trianglehead.counterclockwise` / `.clockwise` replace previous/next.
  - **Artist line:** "Artist – " when the source sends an empty album.
- **Menu bar pill:**
  - **Size:** the "open" pill is 37 × 23pt, ~15.2% white, centered on the icon. It's drawn by `PillWindow`, a click-through window behind the item.
  - **Shape:** continuous corners with an 11pt radius, not a full capsule. Measured from screenshots at 2×, the system pill is 17, 20, 22 and 23pt tall at 3, 5, 7 and 9pt in from its end; a full 11.5pt capsule was 16, 19, 21 and 22pt.
  - **Why not macOS's own highlight:** `button.highlight(true)` on the status item draws nothing on this menu bar (tested on macOS 27), so the pill has to be drawn.
  - **Timing:** it appears instantly on mouse release, because macOS draws its own ~57pt press pill while the mouse is held.
  - **Item width:** the status item uses its natural variable length. A fixed length makes macOS's press pill much wider.
- **Menu bar owl:** 17.2pt tall, which with its thicker outline fills the 18pt icon without clipping. The body outline gets 0.65pt extra weight and the face (eye frames and beak) 0.15pt (`Brand.pathWeights`); more on the face fills it in. Made bigger and bolder so it's recognised faster: at a glance the owl reads by its silhouette, since its eyes are only a few pixels across.
- **Menu bar bear:** solid, 17pt tall (17.5 wide). An outline version was too faint to recognise next to the system icons. It's traced from a black-and-white College Dropout bear sticker (no official vector exists), with the eye whites, eye shine and muzzle cut out (even-odd) and the ear marks dropped. `Resources/bear_template.svg` is the source. Solid logos morph differently: the outline is traced, then the fill fades in.
- **Menu bar XO:** 17pt tall, traced from a black-and-white copy of the XO brush logo and lightly smoothed (`Resources/xo_template.svg`). All its strokes get the 0.4pt extra weight, so they match the owl.
- **Menu bar Cactus Jack:** 16pt tall (it's wider than tall, so the canvas width limits it), traced from a black-and-white copy of the Cactus Jack face logo (`Resources/cactusjack_template.svg`). All lines get 0.5pt extra weight; more merges the mouth stitches. The CACTUS/JACK cross logo was rejected: its letters turn to dots at this size.
- **Menu bar flower:** 16pt tall (width-limited), solid, traced from a GOLF le FLEUR* flower image (`Resources/golf_template.svg`). The two-colour centre is a dot inside a thin gap ring.
- **Menu bar crown:** 17pt tall, traced from the gold crown on the Born Sinner deluxe cover (`Resources/crown_template.svg`). A fan sticker was used first, but it was narrower than the album crown; trace from the album art when it has the symbol, with 0.3pt extra weight; more merges the zigzag points.
- **Faces:** a realistic face (a Lauryn Hill stencil) was tried and dropped. At 17pt the features are 2–3pt and unrecognisable, and a one-color stencil shows as a negative on dark menu bars. Cartoon faces whose features fill the head (the bear, Cactus Jack) work.

## Behaviour notes

- **Spotify:**
  - **Updates:** the `com.spotify.client.PlaybackStateChanged` distributed notification, observed with `.deliverImmediately`. Without it, a menu bar app gets nothing.
  - **Restarting a song:** "previous" partway through a track restarts it, and Spotify posts no notification for that. After previous/next, `SpotifyMonitor.syncPosition` re-reads the position via AppleScript (0.35s later) and corrects the progress bar if it's off by more than 0.5s.
  - **Jumps from elsewhere:** Spotify also posts nothing when the position is changed in Spotify itself, in the system player or from headphones. So while Emblem's player is open, `NowPlayingModel.watchPosition` runs `syncPosition` on opening and every 0.5s after; it stops when the player closes.
  - **Display:** the player shows the notification's main artist only, as Apple does.
- **Brands:** `Brand` lists each artist: names, Spotify artist ID, logo, icon size and palette. Drake is `ovo` (`spotify:artist:3TVXtAsR1Inumwj472S9r4`), Kanye is `kanye` (`spotify:artist:5K4W6rqBFWDnAN6FQUkS6x`, names "Kanye West", "Kanye", "Ye"). The Weeknd is `xo` (`spotify:artist:1Xyo4u8uXC1ZmMpatF05PJ`). Travis Scott is `travis` (`spotify:artist:0Y5tJX1MQlPlqiwlOH1tJY`). Tyler, the Creator is `tyler` (`spotify:artist:4V8LLVI7PbaPR0K2TGSxFF`); his name has a comma, so `ArtistMatcher.credits` keeps brand names that contain separators whole. J. Cole is `cole` (`spotify:artist:6l3HvQ5sa6mXTsMTB19rO5`). Adding an artist means adding a `Brand` and its path data.
- **Artist detection** (`ArtistMatcher`): whole artist names only, so "Drake Bell" and "Yeat" don't count. The lead artist wins: the artist field first, then Spotify's full credits, then "feat./ft./with" in the title.
  - **Full credits:** `SpotifyCredits` reads the track's public embed page, since the notification only names the first artist.
- **Switching brands:** the menu bar traces the old logo out to the circle, then the new one in.
- **Other sources:** `mediaremote-adapter` (git submodule) via `/usr/bin/perl`. If it breaks, only non-Spotify sources are lost.
- **Panel:**
  - **Window:** a borderless panel with `hidesOnDeactivate = false`.
  - **Icon clicks:** handled by a local mouse-down monitor, so the button's own tracking doesn't fight the pill.
- **Artist moment:** when a brand's track starts, a shimmer in its color sweeps across the player once and the cover's glow swells.
- **Player colours come from the album that's playing:** for brand tracks, `ArtworkPalette` picks the art's dominant colour (a hue histogram weighted by saturation, brightness and closeness to the centre) and builds the palette from it: ASTROWORLD gold, IGOR pink, Graduation purple, After Hours red, Views steel blue. Each album gets its own colour, not one per artist. Black-and-white art (House of Balloons, Scorpion, The Idol) gets a silver-on-black player, so the colours always follow the album. Each brand's fixed palette below is only shown until the art arrives. Other songs keep the normal player. `Emblem --palette <image>…` prints the picked colour; `--render-covers <dir> <brand>=<image>…` renders the player with real art.
- **Living background:** for brand tracks, the player's background is a slowly flowing 3×3 `MeshGradient` of four colours from the album art (`ArtworkPalette.meshColors`: the strongest hues at least 40° apart, padded with shades of the main one; greys for black-and-white art), under a 46% black scrim. Like Apple Music's full-screen player. The accent is lightened and softened so text stands out from the same-hue background. macOS 15+; older systems keep the flat background.
- **Premium touches (brand tracks only; the normal player still matches Apple exactly):**
  - **Glass:** on macOS 26 the panel is real glass tinted with the album's accent, with the living background inside at 86% opacity.
  - **Tilting cover:** the cover tilts up to 9° toward the pointer, scales to 102.5% and a soft sheen follows it, like Apple TV posters (`TiltCard`).
  - **Foil logo:** the player's small logo is a metallic gradient in the album's colours whose highlight follows the pointer, or drifts slowly when it's away (`FoilMark`). It sits in a 20pt box in the top-right corner (`Layout.mark`), bigger than the 13.5pt audio-meter slot it used before; the text column stops 4pt short of it.
  - **Menu bar glint:** once a logo finishes tracing in, and on each new track by the same artist, a diagonal streak of light crosses it in 0.9s. The icon is a template, so the glint dims the logo up to 45% outside a full-strength band (`StatusIconRenderer.applyGlint`).
  - **Spring motion:** the menu bar logo grows from 90% with a ~1% overshoot as it traces in, landing at exactly 100% (the resting icon is unchanged). In the player, switching looks, the cover glow and the logo popping in all use springs instead of ease curves. The corner logo pops in around its own centre (`PopIn`): a scale transition grew it from the panel's corner because of its offset.
- **Fallback palettes:**
  - **Kanye:** near-black maroon background, College Dropout gold `#D9A441` accent, and a maroon glow from the top corner.
  - **XO:** near-black background with After Hours red `#E2323C`.
  - **Travis Scott:** warm brown-black with ASTROWORLD gold `#D7B563`, sampled from the cover's gold head. An earlier cactus green was dropped: the palette should come from the artist's album art, not the logo's name.
  - **Tyler:** near-black with IGOR pink `#ECB4CC`, sampled from the cover.
  - **J. Cole:** near-black with the crown's gold `#DBC74C`.

## Open ideas, not done

- **Hide when idle:** hide the icon until something has played, as Apple does.
- **Other menu bars:** scale the pill and positions for 24pt menu bars on external displays and non-notch Macs.
- **Light mode:** check the light menu bar and the brand colors in light mode.
- **Unchecked Apple behaviour:** button hover and press states, the progress bar while dragging, and the 2pt longer bar on hour-long videos.
- **Queue end:** the last song in the queue finishing is untested.
