#!/usr/bin/env ash
# shellcheck shell=dash

# Note that all command line arguments are passed directly to
# email-update.py

set -o nounset
set -o errexit
set -o pipefail

scraper --config /run/secrets/scraper_config.json
python3 email-update.py "$@"
