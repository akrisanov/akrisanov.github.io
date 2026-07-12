#!/usr/bin/env bash
set -euo pipefail

MAGICK=""
if command -v magick >/dev/null 2>&1; then
    MAGICK=$(command -v magick)
elif command -v convert >/dev/null 2>&1; then
    MAGICK=$(command -v convert)
else
    echo "ImageMagick executable not found (expected 'magick' or 'convert')."
    exit 1
fi
FONT=
for candidate in \
  /System/Library/Fonts/Helvetica.ttc \
  /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
  /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
  /usr/share/fonts/truetype/freefont/FreeSans.ttf; do
  if [[ -f "$candidate" ]]; then
    FONT="$candidate"
    break
  fi
 done
if [[ -z "$FONT" ]]; then
  echo "No usable font found. Install DejaVu Sans or Liberation Sans."
  exit 1
fi
OUTPUT_DIR=static/images
mkdir -p "$OUTPUT_DIR"

render_card() {
  local out="$1"
  local title="$2"
  local subtitle="$3"
  local footer="$4"

  echo "Rendering $out"
  local title_img
  local subtitle_img
  local footer_img
  local title_h
  local subtitle_h
  local subtitle_y
  local footer_y

  title_img=$(mktemp /tmp/preview-title-XXXXXX.png)
  subtitle_img=$(mktemp /tmp/preview-subtitle-XXXXXX.png)

  "$MAGICK" -background none -fill '#ff40b9' -font "$FONT" -pointsize 72 \
    -gravity northwest -size 1008x caption:"$title" "$title_img"
  "$MAGICK" -background none -fill '#11c068' -font "$FONT" -pointsize 36 \
    -gravity northwest -size 1008x caption:"$subtitle" "$subtitle_img"

  title_h=$($MAGICK identify -format '%h' "$title_img")
  subtitle_h=$($MAGICK identify -format '%h' "$subtitle_img")
  subtitle_y=$((112 + title_h + 24))

  "$MAGICK" -size 1200x630 xc:'#26212b' \
    -fill '#ff40b9' -draw 'rectangle 96,102 304,108' \
    "$title_img" -geometry +96+112 -composite \
    "$subtitle_img" -geometry +96+${subtitle_y} -composite \
    -font "$FONT" -fill '#efdcff' -pointsize 28 -gravity southeast -annotate +96+24 "$footer" \
    "$OUTPUT_DIR/$out"

  rm -f "$title_img" "$subtitle_img"
}

CARD_LINES=$(python3 <<'PY'
import re
import sys
from pathlib import Path
import tomllib

root = Path('content')

def parse_front_matter(text):
    if not text.startswith('+++'):
        return None
    end = text.find('\n+++', 3)
    if end == -1:
        return None
    block = text[3:end]
    return tomllib.loads(block)

for path in sorted(root.rglob('*.md')):
    if path.name.startswith('_'):
        continue
    rel = path.relative_to(root)
    if rel.name == '_index.md':
        continue

    text = path.read_text(encoding='utf-8')
    meta = parse_front_matter(text)
    if not meta or 'title' not in meta:
        continue

    title = meta['title'].strip()
    footer = 'akrisanov.com'

    tags = []
    if isinstance(meta.get('taxonomies'), dict):
        tags = meta.get('taxonomies', {}).get('tags', []) or []
    if isinstance(tags, str):
        tags = [tags]

    subtitle = ''
    if tags:
        subtitle = ' · '.join(tags)
    elif meta.get('description'):
        desc = meta['description'].strip()
        subtitle = desc.split('. ')[0]
        if len(subtitle) > 80:
            subtitle = subtitle[:77].rstrip() + '...'
    elif isinstance(meta.get('extra'), dict) and meta['extra'].get('keywords'):
        keywords = meta['extra']['keywords']
        if isinstance(keywords, str):
            subtitle = ' · '.join([k.strip() for k in keywords.split(',')][:5])

    slug = rel.with_suffix('').as_posix().replace('/', '-')
    out = f"social-{slug}.png"
    title = title.replace('"', '\\"')
    subtitle = subtitle.replace('"', '\\"')
    footer = footer.replace('"', '\\"')
    print(f'{out}\t{title}\t{subtitle}\t{footer}')
PY
)

while IFS=$'\t' read -r out title subtitle footer; do
  render_card "$out" "$title" "$subtitle" "$footer"
done <<< "$CARD_LINES"

python3 <<'PY'
from pathlib import Path
import tomllib

root = Path('content')
for path in sorted(root.rglob('*.md')):
    if path.name.startswith('_'):
        continue
    text = path.read_text(encoding='utf-8')
    if not text.startswith('+++'):
        continue
    end = text.find('\n+++', 3)
    if end == -1:
        continue
    front_matter = text[3:end]
    try:
        meta = tomllib.loads(front_matter)
    except Exception as exc:
        print(f'ERROR parsing {path}: {exc}')
        continue
    has_thumb = False
    if isinstance(meta, dict) and meta.get('static_thumbnail'):
        has_thumb = True
    extra = meta.get('extra') if isinstance(meta, dict) else None
    if isinstance(extra, dict) and extra.get('static_thumbnail'):
        has_thumb = True
    if has_thumb:
        continue
    rel = path.relative_to(root)
    preview = f"social-{rel.with_suffix('').as_posix().replace('/', '-')}.png"
    insert = f"\nstatic_thumbnail = \"/images/{preview}\"\n"
    new_text = text[:end] + insert + text[end:]
    path.write_text(new_text, encoding='utf-8')
    print(f'Updated {path}')
PY

printf 'Generated preview cards in %s\n' "$OUTPUT_DIR"
