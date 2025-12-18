#!/usr/bin/env bash
# Run test_pd for every rv32ui-p-*.x benchmark.
# - In SIM_OUTPUT_DIR (test_pd): KEEP FULL TRACE (NO TRUNCATION).
# - In RESULT_DIR: extract [W] lines and truncate to 500 lines.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
RESULT_DIR="${ROOT_DIR}/verif/result"

TEST_NAME="${TEST:-test_pd}"
SIMULATOR_NAME="${SIMULATOR:-verilator}"
BENCH_DIR="${ROOT_DIR}/../rv32-benchmarks/individual-instructions"

if [[ ! -d "${BENCH_DIR}" ]]; then
  echo "Benchmark directory not found: ${BENCH_DIR}" >&2
  exit 1
fi

BENCH_DIR=$(cd "${BENCH_DIR}" && pwd)
SIM_OUTPUT_DIR="${ROOT_DIR}/verif/sim/${SIMULATOR_NAME}/${TEST_NAME}"

mkdir -p "${RESULT_DIR}"

shopt -s nullglob
mapfile -t MEM_FILES < <(printf '%s\n' "${BENCH_DIR}"/rv32ui-p-*.x | sort)
shopt -u nullglob

if (( ${#MEM_FILES[@]} == 0 )); then
  echo "No rv32ui-p-*.x files found in ${BENCH_DIR}" >&2
  exit 1
fi

declare -a FAILED_TESTS=()

for MEM_PATH in "${MEM_FILES[@]}"; do
  MEM_BASENAME=$(basename "${MEM_PATH}" .x)
  TRACE_PATH="${SIM_OUTPUT_DIR}/${MEM_BASENAME}.trace"
  OUTPUT_PATH="${RESULT_DIR}/${MEM_BASENAME}.trace"

  echo
  echo "==> Running ${MEM_BASENAME}"

  if ! make -s -C "${SCRIPT_DIR}" TEST="${TEST_NAME}" MEM_PATH="${MEM_PATH}" "$@"; then
    echo "Make failed for ${MEM_BASENAME}" >&2
    FAILED_TESTS+=("${MEM_BASENAME}")
    continue
  fi

  if [[ ! -f "${TRACE_PATH}" ]]; then
    echo "Trace file not found: ${TRACE_PATH}" >&2
    FAILED_TESTS+=("${MEM_BASENAME}")
    continue
  fi

  #
  # --- Process RESULT trace (extract [W] lines, max 500) ---
  #
  if ! grep -F '[W]' "${TRACE_PATH}" > "${OUTPUT_PATH}"; then
    : > "${OUTPUT_PATH}"
  fi

  # Truncate RESULT to first 500 lines
  TMP_RESULT="${OUTPUT_PATH}.tmp"
  if ! head -n 500 "${OUTPUT_PATH}" > "${TMP_RESULT}"; then
    echo "Failed to truncate result: ${OUTPUT_PATH}" >&2
    FAILED_TESTS+=("${MEM_BASENAME}")
    rm -f "${TMP_RESULT}"
    continue
  fi
  mv "${TMP_RESULT}" "${OUTPUT_PATH}"

  #
  # --- IMPORTANT CHANGE: DO NOT TRIM SIM TRACE ---
  #
  # Original code removed here:
  # head -n 500 "${TRACE_PATH}" > "${TRACE_PATH}.trimmed"
  # mv ... ...
  #
  # We now KEEP the sim trace 100% full.

  echo "Wrote [W] lines (max 500) to ${OUTPUT_PATH}; sim trace kept full."
done

if (( ${#FAILED_TESTS[@]} )); then
  echo
  echo "The following tests encountered issues: ${FAILED_TESTS[*]}" >&2
  exit 1
fi