# Docker Setup for IBSng

This guide explains how to run IBSng using Docker and Docker Compose.

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.0 or later
- At least 4GB RAM available
- At least 10GB disk space

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/IBSng.git
cd IBSng
```

### 2. Start Services

```bash
# Start all services (database + application)
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### 3. Access the Application

- **Web Interface**: http://localhost/IBSng/admin
- **Default Credentials**:
  - Username: `system`
  - Password: `system`

- **XML-RPC**: Available on port 1235
- **RADIUS**: Ports 1812 (auth) and 1813 (acct)

## Configuration

### Environment Variables

You can configure the application using environment variables in `docker-compose.yml`:

```yaml
environment:
  IBSNG_DB_HOST: db              # Database host
  IBSNG_DB_PORT: 5432            # Database port
  IBSNG_DB_USER: ibs             # Database user
  IBSNG_DB_PASSWORD: ibsdbpass   # Database password
  IBSNG_DB_NAME: IBSng            # Database name
```

### Using External Database

To use an external PostgreSQL database:

1. Remove or comment out the `db` service in `docker-compose.yml`
2. Set `IBSNG_DB_HOST` to your external database hostname/IP
3. Update other database environment variables as needed

Example:
```yaml
app:
  environment:
    IBSNG_DB_HOST: your-db-host.example.com
    IBSNG_DB_PORT: 5432
    IBSNG_DB_USER: ibs
    IBSNG_DB_PASSWORD: your-secure-password
    IBSNG_DB_NAME: IBSng
```

### Production Configuration

For production, use the production override file:

```bash
# Create .env file with production secrets
cat > .env << EOF
POSTGRES_PASSWORD=your-secure-password
IBSNG_DB_PASSWORD=your-secure-password
IBSNG_DB_HOST=your-production-db-host
EOF

# Start with production settings
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Volumes

The following volumes are created for data persistence:

- `postgres_data`: Database data
- `ibsng_logs`: Application logs
- `ibsng_data`: Application data
- `ibsng_templates`: Smarty templates cache

## Ports

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 80 | TCP | HTTP | Web interface |
| 1235 | TCP | XML-RPC | XML-RPC API server |
| 1812 | UDP | RADIUS | RADIUS authentication |
| 1813 | UDP | RADIUS | RADIUS accounting |
| 5432 | TCP | PostgreSQL | Database (optional, if exposed) |

## Building the Image

To build the Docker image manually:

```bash
docker build -t ibsng:latest .
```

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f app
docker-compose logs -f db
```

### Stop Services

```bash
docker-compose stop
```

### Start Services

```bash
docker-compose start
```

### Restart Services

```bash
docker-compose restart
```

### Remove Everything (including volumes)

```bash
# Stop and remove containers
docker-compose down

# Remove containers and volumes (WARNING: deletes data)
docker-compose down -v
```

### Backup Database

```bash
# Execute backup script inside container
docker-compose exec app /usr/bin/backup_ibs /tmp/backup.sql

# Copy backup from container
docker cp ibsng-app:/tmp/backup.sql ./backup.sql
```

### Restore Database

```bash
# Copy backup to container
docker cp ./backup.sql ibsng-app:/tmp/backup.sql

# Execute restore script
docker-compose exec app /usr/bin/restore_ibs /tmp/backup.sql
```

### Access Container Shell

```bash
# Application container
docker-compose exec app /bin/bash

# Database container
docker-compose exec db /bin/bash
```

### Database Access

```bash
# Connect to PostgreSQL
docker-compose exec db psql -U ibs -d IBSng

# Or from host (if port is exposed)
psql -h localhost -p 5432 -U ibs -d IBSng
```

## Troubleshooting

### Container Won't Start

1. Check logs:
   ```bash
   docker-compose logs app
   ```

2. Check database connectivity:
   ```bash
   docker-compose exec app ping db
   ```

3. Verify environment variables:
   ```bash
   docker-compose exec app env | grep IBSNG
   ```

### Database Connection Issues

1. Ensure database is healthy:
   ```bash
   docker-compose ps db
   ```

2. Check database logs:
   ```bash
   docker-compose logs db
   ```

3. Test connection manually:
   ```bash
   docker-compose exec app psql -h db -U ibs -d IBSng -c "SELECT version();"
   ```

### Permission Issues

If you encounter permission issues:

1. Check volume permissions:
   ```bash
   docker-compose exec app ls -la /var/log/IBSng
   ```

2. Fix permissions if needed:
   ```bash
   docker-compose exec app chmod -R 777 /var/log/IBSng
   ```

### Bandwidth Management Features

For bandwidth management (tc, iptables) to work, you may need to run with additional capabilities:

```yaml
app:
  cap_add:
    - NET_ADMIN
    - SYS_MODULE
  privileged: true  # Use with caution
```

**Note**: Running with `privileged: true` gives the container full system access. Only use in trusted environments.

## Health Checks

Both services include health checks:

- **Database**: Checks if PostgreSQL is ready to accept connections
- **Application**: Checks if IBSng process is running

View health status:
```bash
docker-compose ps
```

## Updating

To update to a new version:

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose build --no-cache
docker-compose up -d
```

## Security Considerations

1. **Change Default Passwords**: Immediately change default admin password
2. **Use Strong Database Passwords**: Set secure passwords in environment variables
3. **Firewall Rules**: Restrict access to exposed ports
4. **SSL/TLS**: Enable SSL for database connections in production
5. **Network Security**: Use Docker networks to isolate services
6. **Volume Security**: Ensure volumes have proper permissions

## Production Deployment

For production deployment:

1. Use `docker-compose.prod.yml` for production settings
2. Set up proper secrets management (Docker secrets, environment files)
3. Configure SSL/TLS for all connections
4. Set up regular backups
5. Configure monitoring and logging
6. Use resource limits
7. Set up health checks and auto-restart policies

## Support

For issues or questions:
- Check logs: `docker-compose logs`
- Review documentation in repository
- Check GitHub issues

---

**Note**: This Docker setup is designed for development and testing. For production, additional security hardening and configuration may be required.

