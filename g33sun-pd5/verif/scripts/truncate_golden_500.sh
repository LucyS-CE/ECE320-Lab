#!/usr/bin/env bash
set -euo pipefail

# Truncate every .trace in verif/golden to 500 lines and write to verif/golden_500.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GOLDEN_DIR="${VERIF_DIR}/golden"
TARGET_DIR="${VERIF_DIR}/golden_500"

mkdir -p "${TARGET_DIR}"

find "${GOLDEN_DIR}" -type f -name '*.trace' -print0 | while IFS= read -r -d '' trace_file; do
  rel_path="${trace_file#${GOLDEN_DIR}/}"
  out_path="${TARGET_DIR}/${rel_path}"
  mkdir -p "$(dirname "${out_path}")"
  head -n 500 "${trace_file}" > "${out_path}"
done

echo "Truncated traces written to ${TARGET_DIR}"
