#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/db"
RETENTION_DAYS=7
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
FILENAME="db_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"
docker exec devops-db pg_dump -U devopsuser devopsdb | gzip > "${BACKUP_DIR}/${FILENAME}"
chmod 600 "${BACKUP_DIR}/${FILENAME}"

echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') Backup created: ${FILENAME}"
find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "[INFO] Pruned backups older than ${RETENTION_DAYS} days"
