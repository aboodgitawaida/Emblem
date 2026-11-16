#!/usr/bin/env bash
# Turns the downloaded media into what the renderer needs:
#   work/page/sixgod.svg  traced hands (potrace), work/page/dog.png  dog cut out of the cover,
#   work/loop/pingpong.mp4 + cn-tower-loop.mp4  the 64 s seamless tower loop.
# Needs: python3 with numpy, pillow, potracer (pip install numpy pillow potracer), ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
A=work/assets; P=work/page; L=work/loop; mkdir -p "$P" "$L"

python3 scripts/trace.py "$A/sixgod.png" "$P/sixgod.svg" 110
python3 scripts/make_dog_matte.py "$A/fatd-cover.jpg" "$P/dog.png"

# Best stretch of the video: 4:08-4:40, the close orbit round the lit pod.
# Played forward then backward so the loop has no jump. 30 fps to save battery.
if [ ! -s "$L/pingpong.mp4" ]; then
  ffmpeg -v error -y -ss 248 -t 32 -i "$A/tower.mp4" -an -vf fps=30 -c:v libx264 -crf 12 -preset fast -g 30 "$L/fwd.mp4"
  rm -f "$L"/rev_*.mp4 "$L/list.txt"
  for i in 7 6 5 4 3 2 1 0; do   # reverse in 4 s chunks so memory stays small
    ffmpeg -v error -y -ss $((i*4)) -t 4 -i "$L/fwd.mp4" -vf reverse -an -c:v libx264 -crf 12 -preset fast -g 30 "$L/rev_$i.mp4"
    echo "file 'rev_$i.mp4'" >> "$L/list.txt"
  done
  ffmpeg -v error -y -f concat -safe 0 -i "$L/list.txt" -c copy "$L/rev.mp4"
  printf "file 'fwd.mp4'\nfile 'rev.mp4'\n" > "$L/both.txt"
  ffmpeg -v error -y -f concat -safe 0 -i "$L/both.txt" -c copy "$L/pingpong.mp4"
fi
# The file the Mac app would play: HEVC, hvc1 tag (hardware decode), no audio, ~51 MB.
[ -s "$L/cn-tower-loop.mp4" ] || ffmpeg -v error -y -i "$L/pingpong.mp4" -an -c:v libx265 -crf 22 -preset medium \
  -tag:v hvc1 -pix_fmt yuv420p -x265-params log-level=error -movflags +faststart "$L/cn-tower-loop.mp4"
echo done
