#!/bin/sh
# Strict explicit publication. Hook sync remains best-effort; this command fails
# if generation fails or exact source content is absent from the latest event.
# Usage: scripts/publish-ledger-entry.sh YYYY-Www-NN
set -eu
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
node "$script_directory/lib/ledger_publication.mjs" "$@"
