# IBSng Dockerized - Deployment Guide

## Docker Image Information

**Registry:** `docker.io/mohseni676/ibsng-dockerized`

**Available Tags:**
- `latest` - Latest stable version
- `v1.0.0` - Version 1.0.0
- `A1.23` - IBSng version A1.23

**Image Size:** ~745MB

**Image Digest:** `sha256:2922258a9bdb1861a80bd37280607b6e0395331f8b6df7faeb2b1055f9705668`

## Quick Start

### Pull the Image

```bash
docker pull mohseni676/ibsng-dockerized:latest
```

### Run with Docker Compose

The recommended way to deploy is using the provided `docker-compose.yml`:

```bash
# Clone or download the repository
git clone <repository-url>
cd ibsng-dockerized

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### Run with Docker Run

```bash
# Start PostgreSQL database
docker run -d \
  --name ibsng-db \
  -e POSTGRES_DB=IBSng \
  -e POSTGRES_USER=ibs \
  -e POSTGRES_PASSWORD=ibsdbpass \
  -v ibsng_postgres_data:/var/lib/postgresql/data \
  postgres:11

# Start IBSng application
docker run -d \
  --name ibsng-app \
  --link ibsng-db:db \
  -p 80:80 \
  -p 1235:1235 \
  -p 1812:1812/udp \
  -p 1813:1813/udp \
  -e IBSNG_DB_HOST=db \
  -e IBSNG_DB_PORT=5432 \
  -e IBSNG_DB_USER=ibs \
  -e IBSNG_DB_PASSWORD=ibsdbpass \
  -e IBSNG_DB_NAME=IBSng \
  mohseni676/ibsng-dockerized:latest
```

## Image Description

This Docker image contains a fully configured IBSng (ISP Billing System) installation, ready for deployment. IBSng is a comprehensive ISP billing and RADIUS server solution.

### Features

- **Web Interface**: Full-featured web-based administration panel
- **XML-RPC API**: Programmatic access via XML-RPC on port 1235
- **RADIUS Server**: Authentication (port 1812) and Accounting (port 1813) support
- **PostgreSQL Integration**: Pre-configured database connectivity
- **Apache Web Server**: Pre-configured with proper permissions
- **Health Checks**: Built-in health monitoring

### Components

- **Base OS**: CentOS 7 (for compatibility with original IBSng installation)
- **Web Server**: Apache 2.4.6 with PHP 5.4.16
- **Database Client**: PostgreSQL client libraries
- **Application**: IBSng A1.23

### Exposed Ports

- **80/tcp**: Web interface (HTTP)
- **1235/tcp**: XML-RPC server
- **1812/udp**: RADIUS authentication
- **1813/udp**: RADIUS accounting

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IBSNG_DB_HOST` | `db` | PostgreSQL database hostname |
| `IBSNG_DB_PORT` | `5432` | PostgreSQL database port |
| `IBSNG_DB_USER` | `ibs` | Database username |
| `IBSNG_DB_PASSWORD` | `ibsdbpass` | Database password |
| `IBSNG_DB_NAME` | `IBSng` | Database name |

### Volumes

The following volumes are recommended for data persistence:

- `/var/log/IBSng` - Application logs
- `/usr/local/IBSng/data` - Application data
- `/usr/local/IBSng/interface/smarty/templates_c` - Template cache

## Access Information

### Web Interface

- **URL**: http://localhost/IBSng/admin
- **Default Username**: `system`
- **Default Password**: `system`

⚠️ **Security Note**: Change the default password immediately after first login!

### Database

- **Host**: As specified in `IBSNG_DB_HOST` (default: `db`)
- **Port**: As specified in `IBSNG_DB_PORT` (default: `5432`)
- **Database**: `IBSng`
- **User**: As specified in `IBSNG_DB_USER` (default: `ibs`)

## Health Check

The image includes a health check that verifies:
1. IBSng process is running
2. Web interface is accessible

Check health status:
```bash
docker inspect --format='{{.State.Health.Status}}' <container-name>
```

## Troubleshooting

### Container Won't Start

1. Check logs: `docker logs <container-name>`
2. Verify database connectivity
3. Check environment variables

### Web Interface Not Accessible

1. Verify Apache is running: `docker exec <container> pgrep httpd`
2. Check Apache error logs: `docker exec <container> tail -f /var/log/httpd/error_log`
3. Verify port mapping: `docker ps` (check port 80)

### Database Connection Issues

1. Ensure database container is running and healthy
2. Verify environment variables match database configuration
3. Test connection: `docker exec <container> psql -h <db-host> -U <user> -d <database>`

## Production Deployment

For production environments:

1. **Use strong passwords**: Set secure database passwords via environment variables
2. **Enable SSL/TLS**: Configure reverse proxy (nginx/traefik) with SSL certificates
3. **Resource limits**: Set appropriate CPU and memory limits
4. **Backup strategy**: Implement regular database backups
5. **Monitoring**: Set up monitoring for containers and services
6. **Network security**: Restrict access to exposed ports via firewall rules

## Support

For issues or questions:
- Check the logs: `docker-compose logs`
- Review the documentation in the repository
- Check container health status

## License

This Docker image is based on IBSng, which is licensed under the MIT License.

---

**Maintainer**: mohseni676  
**Version**: 1.0.0  
**Last Updated**: 2025-11-22

