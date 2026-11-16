# CN Tower background (concept, not built into the app yet)

A moving desktop background for Emblem: a real close-up drone shot of the CN Tower at night, looping, with Drake symbols glowing in the bottom middle and swapping one after another. The project owner signed off on the look in the preview videos. The next step is building it into the Mac app.

## What was decided

- **Footage:** "Toronto Skyline at Night | Stunning Aerials in 4K HDR | DJI Mini 5 Pro" by the YouTube channel *Travelling tour* (`youtube.com/watch?v=T8BD7NZF_ow`). The owner of the video gave permission for personal use. We use 4:08–4:40 (32 s), where the drone circles close to the lit pod (red, pink and white). It plays forward then backward, so the 64 s loop never jumps. It's 1080p at 30 fps.
- **Symbols, in this order, each about 4.6 s:**
  1. **OVO owl:** `Artists/ovo/logo.svg`, gold glow, traces itself in and out.
  2. **6 God praying hands:** the woodcut-style hands with the "6", traced with potrace from a black-on-transparent PNG. Shown as white ink with a soft warm glow, like the T-shirt print.
  3. **For All The Dogs dog:** the official cover art (Apple Music, 2000 × 2000), cut out of its black background. It "draws itself" with a chalk tip: ears, head, eyes, body, then legs (`data/dog_strokes.json`). The drawing uncovers the real artwork, so the finished dog is the original exactly.
- **Placement:** bottom middle, just under the pod; the video is nudged up 54 px (of 1080) to make room.
- **Rejected along the way:**
  - **Live webcams** (SkylineWebcams, the TorontoCNTowerLive YouTube cam): soft at this screen size, and the cam owners hadn't given permission.
  - **Drawn skylines:** the owner wanted real footage.
  - **Solid owl:** rejected.
  - **Symbols tried and dropped:** U of T crest, NOCTA, gold Raptors ball, Certified Lover Boy cover, OVO × Jordan, and emoji-style hands.
  - **Dark backing behind logos:** read as a weird dark hue, so it was removed.
- **Other owl effects** prototyped in the page (pick later): breathing glow, colour sync with the pod (`data/pod_colors.json`), neon start-up flicker, beat pulse when Drake plays, glint with blinking eyes, morph into another artist's logo (XO).

## Files

| Path | What |
|---|---|
| `scripts/fetch_assets.sh` | Downloads the video (from the project owner's Google Drive), the For All The Dogs cover and the hands image into `work/assets/`. Nothing third-party is committed. |
| `scripts/prepare_assets.sh` | Traces the hands, cuts out the dog, and builds the ping-pong loop plus `work/loop/cn-tower-loop.mp4` (HEVC with the `hvc1` tag, ~51 MB: the file the app would play). |
| `scripts/trace.py` | Black-on-light PNG → one SVG path (potracer). |
| `scripts/make_dog_matte.py` | Cover → dog with a clean alpha matte. |
| `renderer/page_template.html` | The animation: logo drawing, glow and every effect. `window.frame(effect, seconds, frameIndex)` draws one frame. |
| `renderer/build_page.py` | Fills the template with logo data into `work/page/index.html`. |
| `renderer/render_frames.js` | Playwright, transparent 1920 × 1080 PNG frames. |
| `renderer/render_video.sh` | Builds `work/preview.mp4` (tower plus logos). `FX=breathe SECS=12` renders another effect. |

`work/` is git-ignored.

## Rebuild the preview

Needs ffmpeg, Node with Playwright, and Python with `numpy pillow potracer`.

```bash
cd concepts/cn-tower-background
```

```bash
./scripts/fetch_assets.sh
```

```bash
./scripts/prepare_assets.sh
```

```bash
./renderer/render_video.sh
```

## Building it into Emblem (next step)

- **Window:** a borderless window at desktop level (`kCGDesktopWindowLevel`), behind the icons, on every Space, ignoring the mouse. It doesn't touch the wallpaper setting in System Settings.
- **Video:** `AVPlayerLooper` over `cn-tower-loop.mp4` (HEVC, hardware decode, muted, 30 fps). The video would live in `~/Library/Application Support/Emblem/Background/`, not in the repo.
- **Logos:** drawn live on top with Core Animation or SwiftUI, reusing the logo outlines Emblem already has. The owl tracing in and out is the same idea as the menu bar morph. Port the hands and dog drawing from `page_template.html` (stroke reveal, then fill fade-in; the dog uses a stroke mask over the image).
- **Battery:**
  - Pause when the desktop window is fully covered (`NSWindow.occlusionState`), when the screen is locked or asleep, or in Low Power Mode, and show a still frame instead.
  - Expect almost no cost most of the time, because windows usually cover the desktop.
- **Settings:** an on/off switch in the menu, and maybe the symbol order and timing.

## Reference: every number and how to change things

### The owner's Mac
- **Model:** MacBook Air 13-inch, M4 (2025), 16 GB.
- **System:** macOS 27.0.1 ("Golden Gate"). Screen 2560 × 1664, with a notch.
- **No fan:** keep always-on effects light.

### Layout (in the 1280 × 720 page space, rendered at 1.5× to 1920 × 1080)
- **Video:** cropped `crop=1920:1026:0:54` then scaled back to 1920 × 1080, which moves it up 54 px.
- **Logo box:** `H = 232` tall, bottom at `BOTTOM = 714`, centred on `x = 640` (`CX`).
  - Per-logo scale `sc`: owl 1, hands 1.04, ball 0.86, NOCTA 0.78, XO 0.82.
- **Dog:** drawn at 1472 × 1828 × 0.175 (about 258 × 320). It's bigger than the others on purpose (the owner asked), so its ears overlap the pod.

### Timing (the `drake` effect)
- **Each symbol:** `IN = 1.3 s` trace in, `HOLD = 2.4 s` glowing, `OUT = 0.9 s` trace out (4.6 s in all).
- **Dog:** draws over `DIN = 2.6 s` (eased), holds, then fades out with a 4% shrink.
- **Hold:** the glow breathes `0.85 + 0.15·sin(2.4·t)`.
- **Trace:** each path gets `pathLength=1` and `stroke-dasharray = progress`. The fill fades in over the second half (`fo = max(0, 2p − 1)`), with a 2.6 pt line plus a blurred glow line.

### Colours and glow
- **Owl:** fill `#FFF1CC`, glow gold `rgb(255,200,97)`.
- **Glow:** three blurred copies (blur 28 at 55%, blur 10 at 90%, blur 3 at 80% mixed with white), then the solid shape.
- **Hands:** fill white, glow `rgb(255,214,140)` at 40% strength. More glow made the woodcut lines mush together.
- **Dog matte:** `alpha = clamp((max(r,g,b) − 40) × 5)`, grown 1 px and blurred 0.6 px, with colour brightened ×1.12. The strokes are fully opaque so the tower's red doesn't show through.

### Adding or swapping a symbol
1. **Get the real image** (the owner wants official logos, not redrawn or emoji versions).
   - Line or ink art: `python3 scripts/trace.py in.png out.svg [threshold]`. It traces dark pixels.
   - Artwork that should stay a picture (like the dog): make a cut-out PNG and use the `pic`/`dogDraw` route.
2. **Load it in `renderer/build_page.py`** (add a `__NAME__` placeholder to the template).
3. **Add an entry to the `SYM` list** in `page_template.html`:
   - `{t:'path', f:(o)=>logo(PATHS, VIEWBOX, 'nonzero'|'evenodd', {...o, glow, fill, sc})}` traces in.
   - `{t:'pic', f:(k,sc)=>pic(...)}` fades and scales in.
4. **Re-run with the new length:** `SECS = symbols × 4.6`, then `./renderer/render_video.sh`.
- **Source of the symbols that were tried and dropped**, if any come back:
  - **Raptors ball:** the `cls-2` paths of `en.wikipedia.org/wiki/Special:FilePath/Toronto_Raptors_logo.svg`, in gold `#E9C877`.
  - **NOCTA:** seeklogo.com's NOCTA (Nike) PNG, traced with the swoosh cropped off.
  - **Certified Lover Boy:** the Apple Music cover.
  - **Jumpman:** `Special:FilePath/Jumpman_logo.svg`.
  - **U of T crest:** `Special:FilePath/Utoronto_coa.svg`.

### Other owl effects already in the page (`FX=<name> ./renderer/render_video.sh`)
- **`breathe`:** glow pulses on a 3.2 s cycle.
- **`colorsync`:** the glow follows the pod's real colour per frame (`data/pod_colors.json`, sampled from the loop's first 12 s). Live in the app, sample the video frame instead.
- **`neon`:** traces in, flickers like a neon sign, then stays lit. Meant for waking the Mac.
- **`beat`:** pulses on a beat (88 BPM demo). In the app, drive it from what Emblem knows is playing, Drake only.
- **`glint`:** a light streak every 3.5 s, the eyes glow, and it blinks every 5.5 s.
- **`morph`:** the owl traces out, the XO traces in, then back. The idea: the background logo follows the artist playing, like the menu bar.

### Ideas list from the brainstorm (not started)
- **Your city:** live skyline with the CN Tower's real nightly colour (cntower.ca publishes a lighting schedule).
- **Uni:** lecture "exam detector" (on-device transcription plus notes), deadline-coloured screen edges, friends' study-status dots.
- **Hands-free:** air gestures over the webcam (Vision hand pose) to skip or pause.
- **With friends:** throwing stickers to nearby friends' Macs (MultipeerConnectivity), a friend's ghost cursor.
- **Toronto and fandom:** Raptors or game-day mode, Drake-drop alerts, "heard in the wild" song map, song time capsule.
- **Fun:** notch eyes, procrastination roast, trophy shelf.

### Battery notes
- **Live streaming all day:** like YouTube nonstop, so avoid it.
- **A local HEVC file at 30 fps:** decoded by the media engine, so it's cheap. It only runs while the desktop is visible.
- **Paused:** a still frame costs about nothing.

### Rights
- **Video:** used with the creator's permission for personal use. Don't ship it in the repo or a public release without asking again.
- **Cover art and hands:** they belong to their owners and are downloaded, not committed.
- **Disclaimer:** keep the project's "not affiliated" note from the main README if this ever ships.
