#!/usr/bin/env bash
# Copy HRMS static files into sites/assets/hrms (real files, not symlinks).
# Required because backend and frontend each have separate Docker volumes
# for sites/assets — nginx cannot follow symlinks into apps/hrms.
set -euo pipefail

BENCH="${BENCH_ROOT:-/home/frappe/frappe-bench}"
SRC="${BENCH}/apps/hrms/hrms/public"
DEST="${BENCH}/sites/assets/hrms"

if [[ ! -d "${SRC}" ]]; then
	echo "HRMS not found at ${SRC} — skipping asset sync"
	exit 0
fi

mkdir -p "${BENCH}/sites/assets"
rm -rf "${DEST}"
cp -a "${SRC}" "${DEST}"
echo "HRMS assets synced to ${DEST}"
