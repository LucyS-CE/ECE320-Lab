#!/usr/bin/env bash
# Extract [W] lines from all trace files in golden_sim directory
# and save them to golden_sim_result directory.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
GOLDEN_SIM_DIR="${ROOT_DIR}/verif/golden_sim"
OUTPUT_DIR="${ROOT_DIR}/verif/golden_sim_result"

if [[ ! -d "${GOLDEN_SIM_DIR}" ]]; then
  echo "Golden sim directory not found: ${GOLDEN_SIM_DIR}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

shopt -s nullglob
mapfile -t TRACE_FILES < <(printf '%s\n' "${GOLDEN_SIM_DIR}"/*.trace | sort)
shopt -u nullglob

if (( ${#TRACE_FILES[@]} == 0 )); then
  echo "No .trace files found in ${GOLDEN_SIM_DIR}" >&2
  exit 1
fi

echo "Processing ${#TRACE_FILES[@]} trace file(s) from golden_sim..."

for TRACE_PATH in "${TRACE_FILES[@]}"; do
  TRACE_BASENAME=$(basename "${TRACE_PATH}")
  OUTPUT_PATH="${OUTPUT_DIR}/${TRACE_BASENAME}"

  echo "  Extracting [W] lines from ${TRACE_BASENAME}..."

  # Extract lines containing [W]
  if ! grep -F '[W]' "${TRACE_PATH}" > "${OUTPUT_PATH}"; then
    # If no [W] lines found, create empty file
    : > "${OUTPUT_PATH}"
  fi

  LINE_COUNT=$(wc -l < "${OUTPUT_PATH}")
  echo "    -> Wrote ${LINE_COUNT} line(s) to ${OUTPUT_PATH}"
done

echo
echo "Done! Extracted [W] lines from ${#TRACE_FILES[@]} file(s) to ${OUTPUT_DIR}"
