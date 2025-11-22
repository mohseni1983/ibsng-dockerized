import os

# Database connection configuration
# Supports both local (Unix socket) and external (TCP/IP) PostgreSQL connections
# For local connection: set DB_HOST=None or "localhost"
# For external connection: set DB_HOST to IP address or hostname

# Support environment variables for external database configuration
DB_HOST = os.environ.get('IBSNG_DB_HOST', None)  # None = Unix socket, or IP/hostname for external
DB_PORT = int(os.environ.get('IBSNG_DB_PORT', '5432'))
DB_USERNAME = os.environ.get('IBSNG_DB_USER', 'ibs')
DB_PASSWORD = os.environ.get('IBSNG_DB_PASSWORD', 'ibsdbpass')
DB_NAME = os.environ.get('IBSNG_DB_NAME', 'IBSng')

# SSL/TLS Configuration for external connections (optional)
# SSL modes: disable, allow, prefer, require, verify-ca, verify-full
DB_SSL_MODE = os.environ.get('IBSNG_DB_SSL_MODE', None)  # None = use default (prefer for external, disable for local)
DB_SSL_CERT = os.environ.get('IBSNG_DB_SSL_CERT', None)
DB_SSL_KEY = os.environ.get('IBSNG_DB_SSL_KEY', None)
DB_SSL_ROOT_CERT = os.environ.get('IBSNG_DB_SSL_ROOT_CERT', None)

# Connection timeout in seconds (for external connections)
DB_CONNECT_TIMEOUT = int(os.environ.get('IBSNG_DB_CONNECT_TIMEOUT', '10'))
