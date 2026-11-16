#!/usr/bin/env bash
# Builds the preview video: tower loop + logo rotation. Output: work/preview.mp4
# Current rotation (owl, 6 God hands, dog) is 3 x 4.6 s = 13.8 s = 414 frames.
set -euo pipefail
cd "$(dirname "$0")/.."
SECS=${SECS:-13.8}; FX=${FX:-drake}; N=$(python3 -c "print(round($SECS*30))")
python3 renderer/build_page.py
rm -rf "work/frames_$FX"; Q=$(( (N+3)/4 ))
for i in 0 1 2 3; do a=$((i*Q)); z=$(( (i+1)*Q < N ? (i+1)*Q : N )); node renderer/render_frames.js $a $z $FX & done; wait
# The video is nudged up 54 px (of 1080) so the logo sits just under the pod.
ffmpeg -v error -y -t "$SECS" -i work/loop/pingpong.mp4 -framerate 30 -i "work/frames_$FX/%04d.png" \
  -filter_complex "[0]crop=1920:1026:0:54,scale=1920:1080,setsar=1[v];[v][1]overlay=shortest=1,format=yuv420p" \
  -an -c:v libx264 -crf 19 -preset medium -movflags +faststart work/preview.mp4
echo work/preview.mp4
