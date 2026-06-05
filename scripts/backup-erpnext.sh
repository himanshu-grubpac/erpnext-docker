#!/usr/bin/env bash
# ERPNext site backup + S3 upload. Run on the EC2 host (not inside a container).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script may live in ~/erpnext/scripts/ or /home/ubuntu/backup-erpnext.sh
if [[ -n "${ERP_DIR:-}" ]]; then
	:
elif [[ "${SCRIPT_DIR}" == */scripts && -f "${SCRIPT_DIR}/../docker-compose.yml" ]]; then
	ERP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
	ERP_DIR="/home/ubuntu/erpnext"
fi

cd "${ERP_DIR}"
if [[ ! -f docker-compose.yml ]]; then
	echo "ERROR: docker-compose.yml not found in ${ERP_DIR}" >&2
	exit 1
fi

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

SITE_NAME="${SITE_NAME:-erp.localhost}"
S3_BUCKET="${S3_BUCKET:-s3://grubpac-erpnext-backups}"
BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/backups}"
LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS:-7}"
S3_RETENTION_DAYS="${S3_RETENTION_DAYS:-30}"
DATE="$(date +%Y-%m-%d_%H-%M)"
COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.hrms.yml)

mkdir -p "${BACKUP_DIR}/${DATE}"

echo "[${DATE}] Starting backup for site ${SITE_NAME}..."
"${COMPOSE[@]}" exec -T backend bench --site "${SITE_NAME}" backup --with-files

CONTAINER_ID="$("${COMPOSE[@]}" ps -q backend)"
docker cp "${CONTAINER_ID}:/home/frappe/frappe-bench/sites/${SITE_NAME}/private/backups/." \
	"${BACKUP_DIR}/${DATE}/"

if command -v aws >/dev/null 2>&1; then
	echo "[${DATE}] Uploading to ${S3_BUCKET}/${DATE}/..."
	aws s3 sync "${BACKUP_DIR}/${DATE}/" "${S3_BUCKET}/${DATE}/"

	CUTOFF="$(date -d "${S3_RETENTION_DAYS} days ago" +%s 2>/dev/null || date -v-"${S3_RETENTION_DAYS}"d +%s)"
	aws s3 ls "${S3_BUCKET}/" | while read -r _ _ folder _; do
		folder="${folder%/}"
		[[ -z "${folder}" ]] && continue
		folder_ts="$(date -d "${folder%_*}" +%s 2>/dev/null || echo 0)"
		if [[ "${folder_ts}" -lt "${CUTOFF}" ]]; then
			echo "[${DATE}] Removing old S3 backup ${folder}"
			aws s3 rm "${S3_BUCKET}/${folder}/" --recursive
		fi
	done
else
	echo "[${DATE}] WARNING: aws CLI not found — backup saved locally only"
fi

find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +"${LOCAL_RETENTION_DAYS}" -exec rm -rf {} +

echo "[${DATE}] Backup completed: ${BACKUP_DIR}/${DATE}/"
