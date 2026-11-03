#!/bin/bash
# usage: tools/render_part.sh N  -> out/RumbStory_01_Ne_otkryvai_partN.mp4 (frames + mix, loudness-normalised)
set -e
P=$1; ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT/studio"
rm -rf out/frames_p$P
node render.mjs --part=$P --frames --fps=12 --workers=2 --soft-gl --chrome=/opt/pw-browsers/chromium-1243/chrome-linux64/chrome 2>&1 | grep --line-buffered -v "WebGL\|uniform1i" | grep --line-buffered -E "frame [0-9]+/[0-9]+ .*eta|to render" | awk 'NR%5==1 {print; fflush()}'
mkdir -p "$ROOT/out"
ffmpeg -v error -y -framerate 12 -i out/frames_p$P/f%05d.jpg -i "$ROOT/audio/mix_p$P.wav" -map 0:v -map 1:a \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -af "loudnorm=I=-15:TP=-1.5:LRA=11" -c:a aac -b:a 192k -ar 48000 \
  -shortest -movflags +faststart "$ROOT/out/RumbStory_01_Ne_otkryvai_part$P.mp4"
echo "done part $P"
