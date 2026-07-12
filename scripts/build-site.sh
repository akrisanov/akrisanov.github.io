#!/usr/bin/env bash
set -euo pipefail

bash scripts/generate-social-previews.sh
zola build
