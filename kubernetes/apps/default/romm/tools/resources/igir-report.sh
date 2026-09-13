#!/bin/sh
set -eu

exec node /scripts/igir-audit.mjs --dry-run
