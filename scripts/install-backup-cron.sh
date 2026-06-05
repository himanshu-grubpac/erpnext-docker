#!/usr/bin/env bash
# Install daily ERPNext backup cron on the EC2 host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERP_DIR="${ERP_DIR:-$(dirname "${SCRIPT_DIR}")}"
BACKUP_DIR="${BACKUP_DIR:-/home/ubuntu/backups}"
CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"
TARGET_SCRIPT="/home/ubuntu/backup-erpnext.sh"

mkdir -p "${BACKUP_DIR}"
chmod +x "${SCRIPT_DIR}/backup-erpnext.sh"
cp "${SCRIPT_DIR}/backup-erpnext.sh" "${TARGET_SCRIPT}"
chmod +x "${TARGET_SCRIPT}"

CRON_LINE="${CRON_SCHEDULE} ERP_DIR=${ERP_DIR} ${TARGET_SCRIPT} >> ${BACKUP_DIR}/backup.log 2>&1"
( sudo crontab -l 2>/dev/null | grep -v "${TARGET_SCRIPT}" || true
	echo "${CRON_LINE}"
) | sudo crontab -

echo "Cron installed:"
sudo crontab -l | grep "${TARGET_SCRIPT}"
echo "Logs: ${BACKUP_DIR}/backup.log"
