#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/infra_health.log"
DISK_THRESHOLD=85
TS() { date '+%Y-%m-%d %H:%M:%S'; }

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

echo "[INFO] $(TS) CPU: ${CPU_USAGE}% | MEM: ${MEM_USAGE}% | DISK: ${DISK_USAGE}%" | tee -a "$LOG_FILE"

if ! systemctl is-active --quiet docker; then
    echo "[WARNING] $(TS) Docker service is NOT running" | tee -a "$LOG_FILE"
fi

APP_STATUS=$(docker inspect -f '{{.State.Status}}' devops-app 2>/dev/null || echo "not_found")
if [ "$APP_STATUS" != "running" ]; then
    echo "[WARNING] $(TS) devops-app container status: ${APP_STATUS}" | tee -a "$LOG_FILE"
fi

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING] $(TS) Disk usage ${DISK_USAGE}% exceeds ${DISK_THRESHOLD}% threshold" | tee -a "$LOG_FILE"
fi
