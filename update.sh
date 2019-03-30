#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

scraper --config /run/secrets/scraper_config.json
./email-update.py \
    --from=code@cyber.dhs.gov \
    --to=jeremy.frasier@trio.dhs.gov \
    --reply=ncats-dev@beta.dhs.gov \
    --json=code.json \
    --subject="Latest code.gov JSON file" \
    --text=body.txt --html=body.html \
    --log-level=debug

#    --cc=ncats-dev@beta.dhs.gov \
