#!/bin/bash
set -euo pipefail

# -------- Config --------
DB_HOST="${DB_HOST:-sqlserver}"
DB_PORT="${DB_PORT:-1433}"
DB_USER="${DB_USER:-sa}"
DB_PASSWORD="${DB_PASSWORD:-Your_strong!Passw0rd}"
SCRIPTS_DIR="${SCRIPTS_DIR:-/scripts}"

SQLCMD="/opt/mssql-tools/bin/sqlcmd"

echo "[db-init] Waiting for SQL Server at ${DB_HOST}, port ${DB_PORT} ..."

# -------- Wait for readiness --------
max_retries=60
retry=0
until ${SQLCMD} -S "${DB_HOST},${DB_PORT}" -U "${DB_USER}" -P "${DB_PASSWORD}" -Q "SELECT 1" -b -o /dev/null; do
  retry=$((retry+1))
  if [ ${retry} -ge ${max_retries} ]; then
    echo "[db-init] ERROR: SQL Server not ready after ${max_retries} attempts."
    exit 1
  fi
  echo "[db-init] SQL not ready yet... retry ${retry}/${max_retries}"
  sleep 2
done

echo "[db-init] SQL Server is ready."

# -------- Run scripts --------
if [ ! -d "${SCRIPTS_DIR}" ]; then
  echo "[db-init] No scripts directory found at ${SCRIPTS_DIR}. Nothing to do."
  exit 0
fi

shopt -s nullglob
FILES=("${SCRIPTS_DIR}"/*.sql)
if [ ${#FILES[@]} -eq 0 ]; then
  echo "[db-init] No .sql files found in ${SCRIPTS_DIR}. Nothing to run."
  exit 0
fi

echo "[db-init] Found ${#FILES[@]} script(s). Executing in order:"
for f in "${FILES[@]}"; do
  echo "  - $(basename "$f")"
done

for f in "${FILES[@]}"; do
  echo "[db-init] Running: $(basename "$f")"
  ${SQLCMD} -S "${DB_HOST},${DB_PORT}" -U "${DB_USER}" -P "${DB_PASSWORD}" -i "$f" -b
  echo "[db-init] Done: $(basename "$f")"
done

echo "[db-init] All scripts executed successfully."
