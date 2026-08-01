#!/usr/bin/env bash
set -euo pipefail

site_dir="${1:-public}"
css_file="$site_dir/css/main.css"
max_css_bytes=35840

if [[ ! -f "$css_file" ]]; then
  echo "Missing generated stylesheet: $css_file" >&2
  exit 1
fi

css_bytes=$(wc -c < "$css_file" | tr -d ' ')
if (( css_bytes > max_css_bytes )); then
  echo "Critical CSS is ${css_bytes} bytes; budget is ${max_css_bytes} bytes." >&2
  exit 1
fi

if [[ ! -f "$site_dir/images/userpic-144.webp" ]]; then
  echo "Missing right-sized WebP header portrait." >&2
  exit 1
fi

failed=0
while IFS= read -r image_tag; do
  if [[ "$image_tag" == *'class=userpic'* ]]; then
    if [[ "$image_tag" != *'width=144'* || "$image_tag" != *'height=144'* ]]; then
      echo "Header portrait is missing its intrinsic dimensions: $image_tag" >&2
      failed=1
    fi
    continue
  fi

  if [[ "$image_tag" != *'width='* || "$image_tag" != *'height='* ]]; then
    echo "Content image is missing intrinsic dimensions: $image_tag" >&2
    failed=1
  fi
  if [[ "$image_tag" != *'loading=lazy'* ]]; then
    echo "Content image is not lazy-loaded: $image_tag" >&2
    failed=1
  fi
done < <(find "$site_dir" -name '*.html' -type f -exec grep -ho '<img[^>]*>' {} +)

if (( failed )); then
  exit 1
fi

echo "Verified performance budgets and image loading hints."
