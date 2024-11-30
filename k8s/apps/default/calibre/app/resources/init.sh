#!/usr/bin/env bash
# shellcheck disable=SC2154
set -euo pipefail

curl -fsL -o prideandprejudice.epub https://www.gutenberg.org/ebooks/1342.epub3.images
calibredb add prideandprejudice.epub --automerge ignore --with-library /config
