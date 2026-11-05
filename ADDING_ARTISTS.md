# Adding an artist

Each artist is one folder with two files. No code changes.

```
Artists/
  travis/
    artist.json   who counts as this artist, sizes and fallback colours
    logo.svg      the logo, as SVG paths
```

Put the folder in **`Artists/`** in the repo to ship it with Emblem, or in
**`~/Library/Application Support/Emblem/Artists/`** to use it only on your Mac without rebuilding (a folder there
with the same name as a built-in one replaces it). The folder's name is the artist's id: short, lowercase, no
spaces (`travis`, `ovo`).

## 1. The logo

1. Find a clean, single-colour version of the logo (black on white is easiest), ideally already an SVG.
2. In a vector editor (Inkscape, Illustrator, Figma), make every shape a plain path: in Inkscape, select all and
   choose **Path → Object to Path**, then **Path → Stroke to Path** for lines. Emblem reads only `<path d="…">`
   elements; circles, rectangles and text must be converted. Arcs (`A` in a path) aren't supported either;
   Object to Path turns them into curves.
3. Save it as `logo.svg` in the folder, then crop its canvas tight around the drawing:

   ```bash
   .build/release/Emblem --fit-logo Artists/<id>/logo.svg
   ```

Holes (eyes, gaps) are cut out when `"fill": "evenOdd"`. What reads well at 17pt: bold silhouettes and cartoon
faces whose features fill the head. Realistic faces and small lettering turn into dots.

## 2. artist.json

Copy one from an existing artist and change it:

```json
{
  "name": "Travis Scott",
  "matchNames": ["Travis Scott"],
  "spotifyArtistID": "0Y5tJX1MQlPlqiwlOH1tJY",
  "logo": { "file": "logo.svg", "fill": "evenOdd", "solid": false },
  "menuBar": { "height": 16, "outlineWeight": 0.5, "outlinedPaths": "all" },
  "player": { "markSize": [13.5, 12.5], "markWeight": 0.6 },
  "colors": {
    "accent": "#D7B563",
    "highlight": [1, 0.95, 0.8],
    "knob": "#F3DFA8",
    "background": [0.07, 0.052, 0.03],
    "ambient": [0.725, 0.557, 0.286, 0.16]
  }
}
```

| Field | What it does |
| --- | --- |
| `name` | The artist's name, for you. |
| `matchNames` | Every name Spotify might credit them as (`["Kanye West", "Kanye", "Ye"]`). Matched as whole credits, ignoring case, so "Drake" doesn't match "Drake Bell". |
| `spotifyArtistID` | From their Spotify page: `open.spotify.com/artist/`**`0Y5tJX1MQlPlqiwlOH1tJY`**. It catches features Spotify's notification doesn't name. |
| `logo.fill` | `"evenOdd"` cuts holes where shapes overlap (most logos); `"nonZero"` fills them. |
| `logo.solid` | `true` for solid shapes (the bear, the flower): the menu bar traces the outline, then fades the fill in. `false` for line drawings, which draw stroke by stroke. |
| `menuBar.height` | Logo height in the 18pt icon, usually 16–17.2. Wide logos are limited by the width instead. |
| `menuBar.outlineWeight` | Extra line weight (pt) so thin lines don't fade at menu bar size: 0.3–0.65 for line art, 0 for solid logos. |
| `menuBar.outlinedPaths` | Which paths get that weight: `"all"`, or path numbers (`0` first, `-1` last). |
| `menuBar.extraWeights` | Optional extra weight for single paths, e.g. `{"2": 0.15}`. |
| `player.markSize` | The small logo's size (pt) in the player's top-right corner, about `[12, 12.5]`. |
| `player.markWeight` | Optional extra line weight for that small logo. |
| `colors` | The player's colours until the album art loads (after that they come from the cover). Each is `"#RRGGBB"`, or `[r, g, b]` / `[r, g, b, opacity]` from 0 to 1. `accent`: text, controls and progress. `highlight`: the shimmer's bright centre. `knob`: the progress knob. `background`: the panel. `ambient`: a soft glow from the top corner (use some opacity). |

To pick an accent from an album cover: `.build/release/Emblem --palette cover.jpg`.

## 3. Check it

```bash
swift build -c release
.build/release/Emblem --check-artists            # every artist that loads, and what's wrong with any that don't
.build/release/Emblem --render-frames /tmp/emblem  # morph_<id>.png and player_<id>.png to look at
```

`--check-artists` explains problems in plain words (a missing field, a bad Spotify ID, a colour it can't read, two
artists sharing a name). Emblem skips a broken folder and keeps working with the rest.

Optionally, add a couple of cases for the new artist to `ArtistMatcher.selfTest()` (a lead credit, a feature) and
run `.build/release/Emblem --selftest`.

## 4. Use it

- **In `Artists/`:** `./scripts/build-app.sh --install`.
- **In your own folder:** quit Emblem (right-click its icon) and open it again.

Play one of their songs on Spotify: the icon traces into the logo.

The logos belong to their owners; see the disclaimer in the README before shipping one in the repo.
