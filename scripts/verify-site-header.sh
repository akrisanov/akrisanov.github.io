#!/usr/bin/env bash
set -euo pipefail

readonly output_dir="${1:-public}"
readonly expected_subtitle="Production LLM inference, AI infrastructure, and distributed systems"
readonly expected_navigation='href="?/about/"?.*href="?/files/andrey-krisanov-resume.pdf"?.*href="?https://github.com/akrisanov"?.*href="?https://www.linkedin.com/in/akrisanov/"?'

if [[ ! -d "$output_dir" ]]; then
  echo "Build output directory does not exist: $output_dir" >&2
  exit 1
fi

status=0
while IFS= read -r -d '' page; do
  compact_html="$(tr '\n' ' ' < "$page")"

  # Zola redirect stubs intentionally contain no shared site chrome.
  if [[ "$compact_html" == *"<title>Redirect</title>"* ]]; then
    continue
  fi

  if [[ ! "$compact_html" =~ \<header\ class=\"?flag ]]; then
    echo "Missing shared site header: $page" >&2
    status=1
    continue
  fi

  if [[ "$compact_html" != *"$expected_subtitle"* ]]; then
    echo "Missing shared site subtitle: $page" >&2
    status=1
  fi

  if ! grep -Eq "$expected_navigation" <<< "$compact_html"; then
    echo "Missing or inconsistent shared navigation: $page" >&2
    status=1
  fi
done < <(find "$output_dir" -type f -name '*.html' -print0)

if (( status != 0 )); then
  exit "$status"
fi

echo "Verified shared subtitle and navigation in every generated HTML page."
