#!/bin/sh
# Owner convenience: install the shim from THIS dev checkout and register the checkout in ~/.gbg/dev.
# The contract is `gbg install` run from a pinned copy (docs/ARCHITECTURE.md D2); this only shortens the owner's path.
set -eu
cd "$(dirname "$0")"
exec julia --startup-file=no --project="$PWD" -e 'using GBGCodingTools; exit(GBGCodingTools.main(ARGS))' -- install --dev-checkout "$PWD"
