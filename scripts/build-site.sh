#!/usr/bin/env bash
set -euo pipefail

bash scripts/generate-social-previews.sh
zola build
bash scripts/verify-site-header.sh public
