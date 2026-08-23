#!/usr/bin/env bash
set -euo pipefail

readonly output_dir="${1:-public}"

if [[ ! -d "$output_dir" ]]; then
  echo "Build output directory does not exist: $output_dir" >&2
  exit 1
fi

status=0
while IFS= read -r -d '' page; do
  compact_html="$(tr '\n' ' ' < "$page")"

  # Zola redirect stubs are intentionally minimal and must stay out of sitemap.xml.
  if [[ "$compact_html" == *"<title>Redirect</title>"* ]]; then
    continue
  fi

  for marker in \
    '<title>' \
    'name=description' \
    'name=robots' \
    'property=og:title' \
    'property=og:description' \
    'property=og:image' \
    'property=og:image:alt' \
    'name=twitter:card' \
    'name=twitter:creator' \
    'name=twitter:image:alt' \
    'type=application/ld+json'; do
    if [[ "$compact_html" != *"$marker"* ]]; then
      echo "Missing SEO marker '$marker': $page" >&2
      status=1
    fi
  done

  if [[ "$page" != "$output_dir/404.html" && "$compact_html" != *"rel=canonical"* ]]; then
    echo "Missing canonical URL: $page" >&2
    status=1
  fi

  if ! perl -0ne 'while (/<script type=application\/ld\+json>(.*?)<\/script>/sg) { print "$1\n" }' "$page" | jq -e . >/dev/null; then
    echo "Invalid JSON-LD: $page" >&2
    status=1
  fi

  if ! perl -0ne 'while (/<script type=application\/ld\+json>(.*?)<\/script>/sg) { print "$1\n" }' "$page" | jq -s -e '
    def valid_profile_datetime:
      . as $value
      | (($value | type) == "string")
        and (($value | try fromdateiso8601 catch null) != null);

    [.. | objects | select(."@type" == "ProfilePage")] as $profiles
    | all($profiles[];
        (.dateCreated | valid_profile_datetime)
        and (.dateModified | valid_profile_datetime)
      )
  ' >/dev/null; then
    echo "ProfilePage dates must be ISO 8601 UTC datetimes: $page" >&2
    status=1
  fi
done < <(find "$output_dir" -type f -name '*.html' -print0)

if grep -Fq '<loc>https://akrisanov.com/blog/</loc>' "$output_dir/sitemap.xml"; then
  echo "Redirect URL found in sitemap.xml: https://akrisanov.com/blog/" >&2
  status=1
fi

if ! grep -Fq 'Sitemap: https://akrisanov.com/sitemap.xml' "$output_dir/robots.txt"; then
  echo "robots.txt does not advertise sitemap.xml" >&2
  status=1
fi

if (( status != 0 )); then
  exit "$status"
fi

echo "Verified metadata, canonicals, JSON-LD, robots.txt, and sitemap.xml."
