#!/bin/bash
# Runs gen-all.pl against ~/RiverRats/<year> and compares outputs to golden.
# Invokes meld on the output directories if any file has changed.
#
# Usage: run-tests.sh [year]   (default: 2026)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="${SCRIPT_DIR}/golden"
YEAR=${1:-2026}
DATA_DIR="${HOME}/Documents/Data/RiverRats/${YEAR}"
GEN_ALL="${SCRIPT_DIR}/../gen-all.pl"

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
    cp "${DATA_DIR}/${s}/Attendance"*.csv "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
    cp "${DATA_DIR}/${s}/Attendance.txt"   "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
    cp "${DATA_DIR}/${s}/sailing-level-counts.csv" "${ACTUAL_DIR}/${s}/" 2>/dev/null || true
done
cp "${DATA_DIR}/TShirts.csv"              "${ACTUAL_DIR}/" 2>/dev/null || true
cp "${DATA_DIR}/sailing-level-counts.csv" "${ACTUAL_DIR}/" 2>/dev/null || true

echo "Comparing outputs against golden (${GOLDEN_DIR}) ..."
if diff -r "${GOLDEN_DIR}" "${ACTUAL_DIR}" > /dev/null 2>&1; then
    echo "All outputs match golden. PASS."
else
    echo ""
    echo "Differences found:"
    diff -r "${GOLDEN_DIR}" "${ACTUAL_DIR}" || true
    echo ""
    echo "Launching meld ..."
    meld "${GOLDEN_DIR}" "${ACTUAL_DIR}"
fi
