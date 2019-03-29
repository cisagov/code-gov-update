#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

scraper --config /run/secrets/scraper_config.json
./email-update.py --from=reports@cyber.dhs.gov --to=jeremy.frasier@trio.dhs.gov
