#!/usr/bin/env bash
# Copy every Doink move folder into assets/, normalizing frame names to NN.png
# (handles mixed-case .png/.PNG and skips Thumbs.db). Animation folder names are
# sanitized to lowercase_snake (Godot-friendly).
set -euo pipefail
SRC="/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sprites/Doink_sprites/Doink The Clown"
DEST="assets/sprites/doink"
mkdir -p "$DEST"

find "$SRC" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  raw="$(basename "$dir")"
  anim="$(echo "$raw" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9_' )"
  mkdir -p "$DEST/$anim"
  i=1
  find "$dir" -maxdepth 1 -type f -iname '*.png' | sort -V | while read -r f; do
    printf -v out '%02d.png' "$i"
    cp "$f" "$DEST/$anim/$out"
    i=$((i+1))
  done
  echo "$anim ($(ls "$DEST/$anim" | wc -l) frames)"
done
echo "total animations: $(find "$DEST" -mindepth 1 -maxdepth 1 -type d | wc -l)"
