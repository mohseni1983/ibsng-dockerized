#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
  if PGPASSWORD=${IBSNG_DB_PASSWORD:-ibsdbpass} psql -h "${IBSNG_DB_HOST:-db}" -p "${IBSNG_DB_PORT:-5432}" -U "${IBSNG_DB_USER:-ibs}" -d "${IBSNG_DB_NAME:-IBSng}" -c '\q' 2>/dev/null; then
    echo "PostgreSQL is ready!"
    break
  fi
  echo "PostgreSQL is unavailable - sleeping ($i/30)"
  sleep 1
done

# Initialize database if needed (only if tables don't exist)
if ! PGPASSWORD=${IBSNG_DB_PASSWORD:-ibsdbpass} psql -h "${IBSNG_DB_HOST:-db}" -p "${IBSNG_DB_PORT:-5432}" -U "${IBSNG_DB_USER:-ibs}" -d "${IBSNG_DB_NAME:-IBSng}" -c '\dt' 2>/dev/null | grep -q "defs"; then
    echo "Database not initialized. Running initialization..."
    export IBSNG_DB_HOST=${IBSNG_DB_HOST:-db}
    export IBSNG_DB_PORT=${IBSNG_DB_PORT:-5432}
    export IBSNG_DB_USER=${IBSNG_DB_USER:-ibs}
    export IBSNG_DB_PASSWORD=${IBSNG_DB_PASSWORD:-ibsdbpass}
    export IBSNG_DB_NAME=${IBSNG_DB_NAME:-IBSng}
    
    # Run initialization script (non-interactive)
    cd /usr/local/IBSng
    python scripts/init.py || echo "Initialization completed with warnings"
else
    echo "Database already initialized. Skipping initialization."
fi

# Start Apache in background
echo "Starting Apache..."
httpd -D FOREGROUND &

# Start IBSng
echo "Starting IBSng..."
cd /usr/local/IBSng
exec python -OO -W ignore::: ibs.py

