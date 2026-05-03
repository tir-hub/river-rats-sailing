#!/bin/bash
# Runs gen-all.pl against ~/Documents/Data/RiverRats/<year> and compares outputs to golden.
# Invokes meld on the output directories if any file has changed.
#
# Usage: run-tests.sh [--update-golden] [year]   (year defaults to 2026)
#
#   --update-golden   After running, copy outputs to golden instead of diffing.
#                     Use this after confirming that changed output is intentional.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="${SCRIPT_DIR}/golden"
GEN_ALL="${SCRIPT_DIR}/../gen-all.pl"
UPDATE_GOLDEN=0
YEAR=2026

for arg in "$@"; do
    case "${arg}" in
        --update-golden) UPDATE_GOLDEN=1 ;;
        *) YEAR="${arg}" ;;
    esac
done

DATA_DIR="${HOME}/Documents/Data/RiverRats/${YEAR}"

if [ ! -d "${DATA_DIR}" ]; then
    echo "ERROR: data directory not found: ${DATA_DIR}"
    exit 1
fi

echo "Running gen-all.pl --data-dir ${DATA_DIR} ..."
perl "${GEN_ALL}" --data-dir "${DATA_DIR}"
echo ""

# Collect just the output files into a temp dir matching the golden structure
ACTUAL_DIR=$(mktemp -d)
trap 'rm -rf "${ACTUAL_DIR}"' EXIT

for s in Session-{1..7}; do
    mkdir -p "${ACTUAL_DIR}/${s}"
    cp "${DATA_DIR}/${s}/Attendance"*.csv             "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
    cp "${DATA_DIR}/${s}/Attendance.txt"              "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
    cp "${DATA_DIR}/${s}/sailing-level-counts.csv"    "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
done
cp "${DATA_DIR}/TShirts.csv"              "${ACTUAL_DIR}/" 2>/dev/null || true
cp "${DATA_DIR}/sailing-level-counts.csv" "${ACTUAL_DIR}/" 2>/dev/null || true

if [ "${UPDATE_GOLDEN}" -eq 1 ]; then
    cp -r "${ACTUAL_DIR}/." "${GOLDEN_DIR}/"
    echo "Golden files updated from ${DATA_DIR}."
else
    echo "Comparing outputs against golden (${GOLDEN_DIR}) ..."
    if diff -r "${GOLDEN_DIR}" "${ACTUAL_DIR}" > /dev/null 2>&1; then
        echo "All outputs match golden. PASS."
    else
        echo ""
        echo "Differences found:"
        diff -r "${GOLDEN_DIR}" "${ACTUAL_DIR}" || true
        echo ""
        if command -v meld &>/dev/null; then
            echo "Launching meld ..."
            meld "${GOLDEN_DIR}" "${ACTUAL_DIR}"
        elif command -v opendiff &>/dev/null; then
            echo "Launching opendiff ..."
            opendiff "${GOLDEN_DIR}" "${ACTUAL_DIR}"
        else
            echo "No visual diff tool found (install meld on Linux, or Xcode Command Line Tools on macOS for opendiff)"
        fi
    fi
fi
