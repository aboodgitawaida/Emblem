#!/usr/bin/env bash
# Downloads the third-party media this concept uses into work/assets/.
# None of it is committed: the video belongs to its creator (shared with
# permission for personal use), the cover art to Drake/OVO, the hands art to its owners.
set -euo pipefail
cd "$(dirname "$0")/.."
A=work/assets; mkdir -p "$A"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

# 1. CN Tower night drone video, 1080p60, 7.5 min ("Toronto Skyline at Night | Stunning
#    Aerials in 4K HDR | DJI Mini 5 Pro", channel "Travelling tour", youtube.com/watch?v=T8BD7NZF_ow).
#    The owner gave permission; the 1080p MP4 sits in the project owner's Google Drive folder
#    https://drive.google.com/drive/folders/1B75j6uYzgIRgc5FMwibt__5tuq4exhYR
[ -s "$A/tower.mp4" ] || curl -fL -A "$UA" -o "$A/tower.mp4" \
  "https://drive.usercontent.google.com/download?id=10bfceOXisgQcBAJEUVIRpWMndU7bAVyu&export=download&confirm=t"

# 2. For All The Dogs cover (official artwork, 2000 x 2000) via Apple's public search API.
if [ ! -s "$A/fatd-cover.jpg" ]; then
  url=$(curl -fsS "https://itunes.apple.com/search?term=drake+for+all+the+dogs&entity=album&limit=5" |
    python3 -c "import json,sys; r=[x for x in json.load(sys.stdin)['results'] if x['collectionName']=='For All The Dogs'][0]; print(r['artworkUrl100'].replace('100x100bb','2000x2000bb'))")
  curl -fsS -o "$A/fatd-cover.jpg" "$url"
fi

# 3. 6 God praying hands (with the 6), black on transparent, 860 x 571.
#    Page: https://www.vhv.rs/viewpic/hoTRTJR_drake-praying-hands-png-transparent-png/
[ -s "$A/sixgod.png" ] || curl -fsS -A "$UA" -e "https://www.vhv.rs/" -o "$A/sixgod.png" \
  "https://www.vhv.rs/dpng/d/443-4432456_drake-praying-hands-png-transparent-png.png"

echo "Assets in $A:"; ls -la "$A"
