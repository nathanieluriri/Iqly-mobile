#!/usr/bin/env bash
# Renders the preview films (all of film/flows, or the names given) into
# film/out, each with a contact sheet and the frames after every tap.
set -euo pipefail
cd "$(dirname "$0")/.."

out=film/out
mkdir -p "$out"

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for flow in film/flows/*_film.dart; do
    names+=("$(basename "$flow" _film.dart)")
  done
fi

for name in "${names[@]}"; do
  started=$(date +%s)
  flutter test "film/flows/${name}_film.dart"
  took=$(($(date +%s) - started))
  mp4="$out/$name.mp4"
  duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$mp4")

  rows=$(awk -v d="$duration" 'BEGIN { n = d * 2; n = (n == int(n)) ? n : int(n) + 1; print int((n + 7) / 8) }')
  ffmpeg -nostdin -v error -y -i "$mp4" -vf "fps=2,scale=270:-1,tile=8x$rows:color=0x1e1e1e" -frames:v 1 "$out/$name-sheet.png"

  # The second after each tap at 30 fps, cropped to the phone screen and
  # scaled to its 390 pt width so frames line up with the Figma frames.
  frames="$out/$name-transitions"
  rm -rf "$frames"
  mkdir -p "$frames"
  while IFS=$'\t' read -r at tap; do
    ffmpeg -nostdin -v error -y -ss "$at" -t 1 -i "$mp4" \
      -vf "fps=30,crop=780:1688:150:116,scale=390:-1" \
      -start_number 0 "$frames/$tap-%02d.png"
  done <"$out/$name.taps"

  printf '%s: %.2f s of film, rendered in %d s\n' "$name" "$duration" "$took" |
    tee -a "$out/render.log"
done
