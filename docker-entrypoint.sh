#!/bin/bash
set -e

# Check if we're in Docker (systemd not available)
IN_DOCKER=false
if [ ! -d /run/systemd/system ]; then
    IN_DOCKER=true
fi

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
    # Skip systemctl commands in Docker
    cd /usr/local/IBSng
    if [ "$IN_DOCKER" = "true" ]; then
        # Patch init.py to skip systemctl commands
        python -c "
import sys
sys.path.insert(0, '/usr/local/IBSng')
import os
# Mock systemctl for Docker
original_system = os.system
def mock_systemctl(cmd):
    if 'systemctl' in cmd:
        return 0  # Success
    return original_system(cmd)
os.system = mock_systemctl
exec(open('/usr/local/IBSng/scripts/init.py').read())
" || echo "Initialization completed with warnings"
    else
        python scripts/init.py || echo "Initialization completed with warnings"
    fi
else
    echo "Database already initialized. Skipping initialization."
fi

# Start Apache in background
echo "Starting Apache..."
httpd -D FOREGROUND &
APACHE_PID=$!
sleep 2

# Verify Apache started
if ! kill -0 $APACHE_PID 2>/dev/null; then
    echo "ERROR: Apache failed to start"
    exit 1
fi
echo "Apache started with PID $APACHE_PID"

# Start IBSng
echo "Starting IBSng..."
cd /usr/local/IBSng
python -OO -W ignore::: ibs.py &
IBSNG_PID=$!
sleep 3

# Keep container alive - monitor both Apache and IBSng processes
echo "Waiting for processes..."
while true; do
    # Check Apache
    if ! kill -0 $APACHE_PID 2>/dev/null && ! pgrep -f "httpd" > /dev/null; then
        echo "Apache process died, restarting..."
        httpd -D FOREGROUND &
        APACHE_PID=$!
        sleep 2
    fi
    
    # Check IBSng
    if ! pgrep -f "ibs.py" > /dev/null && ! pgrep -f "IBSng" > /dev/null; then
        echo "IBSng process not found, but continuing..."
    fi
    
    sleep 10
done

