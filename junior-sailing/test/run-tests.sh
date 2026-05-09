#!/bin/bash
# Runs gen-all.pl against the local synthetic test data and compares outputs to golden.
# Invokes meld on the output directories if any file has changed.
#
# Usage: run-tests.sh [--update-golden]
#
#   --update-golden   Write new outputs into golden instead of comparing.
#                     Use this after confirming that changed output is intentional.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPARE="--compare-only"
for arg in "$@"; do
    case "${arg}" in
        --update-golden) COMPARE="" ;;
    esac
done

exec perl "${SCRIPT_DIR}/../gen-all.pl" \
    --data-dir   "${SCRIPT_DIR}/data" \
    --output-dir "${SCRIPT_DIR}/golden" \
    ${COMPARE}
