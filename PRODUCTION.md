# Sentry Self-Hosted - Production Deployment

This is a simplified, production-ready deployment of Sentry using a single Docker Compose file.

## Features

- **Single Command Deployment**: Just `docker compose up -d`
- **Automatic Initialization**: Secret generation, database migrations, and setup handled automatically
- **Volume-Based Configuration**: All configuration stored in Docker volumes
- **Minimal File Clutter**: Only volumes for user data are external
- **Production Ready**: Optimized for production deployments

## Quick Start

### 1. Prerequisites

- Docker Engine 20.10+ with Compose V2
- At least 4GB RAM (8GB+ recommended)
- 20GB+ disk space

### 2. Initial Setup

```bash
# Copy the environment file
cp .env.example .env

# Edit the configuration
nano .env
```

**Required Configuration:**

- Set `SENTRY_MAIL_HOST` to your mail server hostname
- Optionally customize `SENTRY_SYSTEM_SECRET_KEY` (will auto-generate if not set)

### 3. Deploy

```bash
# Start all services
docker compose -f docker-compose.production.yml --env-file .env up -d

# Watch the initialization (first run only)
docker compose -f docker-compose.production.yml --env-file .env logs -f init

# Once init is complete, all services will start automatically
```

### 4. Create Admin User

On first deployment, you'll be prompted to create an admin user:

```bash
docker compose -f docker-compose.production.yml --env-file .env run --rm web createuser
```

### 5. Access Sentry

Open your browser to: `http://localhost:9000` (or your configured `SENTRY_BIND` port)

## Configuration

### Environment Variables

All configuration is done through `.env`:

| Variable                      | Required | Description               | Default          |
| ----------------------------- | -------- | ------------------------- | ---------------- |
| `SENTRY_SYSTEM_SECRET_KEY`    | Yes      | Secret key for encryption | Auto-generated   |
| `SENTRY_MAIL_HOST`            | Yes      | Mail server hostname      | -                |
| `SENTRY_BIND`                 | No       | Port to expose Sentry     | 9000             |
| `COMPOSE_PROFILES`            | No       | Features to enable        | feature-complete |
| `SENTRY_EVENT_RETENTION_DAYS` | No       | Days to retain events     | 90               |

See `.env.example` for all available options.

### Compose Profiles

Choose the features you need:

- **`feature-complete`** (default): All Sentry features including performance monitoring, profiling, replays, etc.
- **`errors-only`**: Minimal setup for error monitoring only (uses fewer resources)

Set in `.env`:

```env
COMPOSE_PROFILES=errors-only
```

### Custom Configuration

Advanced configuration can be done by editing files in the Docker volumes after first run:

```bash
# List configuration volumes
docker volume ls | grep sentry-.*-config

# Edit Sentry config
docker run --rm -v sentry-config:/config -it alpine vi /config/config.yml

# Edit Sentry Python config
docker run --rm -v sentry-config:/config -it alpine vi /config/sentry.conf.py
```

## Operations

### View Logs

```bash
# All services
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f web

# Last 100 lines
docker compose -f docker-compose.production.yml logs --tail=100
```

### Restart Services

```bash
# Restart all
docker compose -f docker-compose.production.yml restart

# Restart specific service
docker compose -f docker-compose.production.yml restart web
```

### Stop/Start

```bash
# Stop all services (data is preserved)
docker compose -f docker-compose.production.yml stop

# Start all services
docker compose -f docker-compose.production.yml start

# Stop and remove containers (data still preserved in volumes)
docker compose -f docker-compose.production.yml down
```

### Upgrade Sentry

```bash
# Update .env with new image versions
nano .env

# Pull new images
docker compose -f docker-compose.production.yml pull

# Recreate containers with new images
docker compose -f docker-compose.production.yml up -d

# Watch the upgrade process
docker compose -f docker-compose.production.yml logs -f init web
```

### Run Database Migrations

Migrations run automatically during init. To run manually:

```bash
docker compose -f docker-compose.production.yml run --rm web upgrade
```

### Create Additional Users

```bash
docker compose -f docker-compose.production.yml run --rm web createuser
```

### Run Sentry Shell

```bash
docker compose -f docker-compose.production.yml run --rm web shell
```

## Data Management

### Backup

All persistent data is stored in Docker volumes:

```bash
# List data volumes
docker volume ls | grep sentry-postgres
docker volume ls | grep sentry-redis
docker volume ls | grep sentry-kafka
docker volume ls | grep sentry-clickhouse
docker volume ls | grep sentry-seaweedfs

# Backup a volume (example: postgres)
docker run --rm \
  -v sentry-postgres:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/sentry-postgres-backup.tar.gz -C /data .
```

### Restore

```bash
# Stop services
docker compose -f docker-compose.production.yml down

# Restore a volume (example: postgres)
docker run --rm \
  -v sentry-postgres:/data \
  -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/sentry-postgres-backup.tar.gz"

# Start services
docker compose -f docker-compose.production.yml up -d
```

### Clean Up Old Data

Cleanup runs automatically via the `sentry-cleanup` cron job based on `SENTRY_EVENT_RETENTION_DAYS`.

To run manually:

```bash
docker compose -f docker-compose.production.yml run --rm web cleanup --days 90
```

### Reset Everything

**WARNING: This will delete all data!**

```bash
# Stop and remove containers
docker compose -f docker-compose.production.yml down

# Remove all volumes
docker volume rm $(docker volume ls -q | grep sentry-)

# Start fresh
docker compose -f docker-compose.production.yml up -d
```

## Monitoring

### Health Checks

All services have built-in health checks:

```bash
# View service health status
docker compose -f docker-compose.production.yml ps
```

### Resource Usage

```bash
# View resource usage
docker stats

# View disk usage
docker system df -v
```

### StatsD Integration

Sentry can send metrics to a StatsD server. Set in `.env`:

```env
STATSD_ADDR=your-statsd-server:8125
```

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker compose -f docker-compose.production.yml logs

# Check specific service
docker compose -f docker-compose.production.yml logs postgres
docker compose -f docker-compose.production.yml logs kafka
docker compose -f docker-compose.production.yml logs clickhouse
```

### Initialization Failed

```bash
# Re-run initialization
docker compose -f docker-compose.production.yml up init --force-recreate

# Check init logs
docker compose -f docker-compose.production.yml logs init
```

### Out of Memory

Increase Docker memory limit or adjust ClickHouse memory usage in `.env`:

```env
# Lower ClickHouse memory usage (default is 0.3 = 30% of host memory)
# Set MAX_MEMORY_USAGE_RATIO via custom ClickHouse config
```

### Slow Performance

- Increase Docker resources (CPU, memory, disk)
- Use SSD storage for Docker volumes
- Adjust retention period to reduce data volume
- Consider using `errors-only` profile if you don't need full features

## Architecture

### Services

- **nginx**: Reverse proxy and load balancer
- **web**: Sentry web application
- **cron**: Scheduled cleanup tasks
- **worker**: Background task workers
- **relay**: Event ingestion proxy
- **postgres**: Main database
- **clickhouse**: Analytics database
- **kafka**: Message queue
- **redis**: Cache and task queue
- **symbolicator**: Debug symbol processing
- **snuba**: Analytics query engine
- **vroom**: Profiling service (feature-complete only)
- **uptime-checker**: Uptime monitoring (feature-complete only)

### Volumes

**Data Volumes** (persist user data):

- `sentry-data`: Uploaded files and artifacts
- `sentry-postgres`: PostgreSQL database
- `sentry-redis`: Redis data
- `sentry-kafka`: Kafka message logs
- `sentry-clickhouse`: ClickHouse analytics data
- `sentry-seaweedfs`: S3-compatible object storage
- `sentry-symbolicator`: Cached debug symbols
- `sentry-vroom`: Profiling data

**Configuration Volumes** (managed by init container):

- `sentry-config`: Sentry configuration files
- `sentry-relay-config`: Relay configuration
- `sentry-*-config`: Various service configurations

**Ephemeral Volumes** (can be deleted):

- `sentry-nginx-cache`: Nginx cache
- `sentry-kafka-log`: Kafka logs

## Security Considerations

1. **Change Default Credentials**: Ensure `SENTRY_SYSTEM_SECRET_KEY` is set to a strong random value
2. **Network Isolation**: Consider using Docker networks to isolate services
3. **TLS/SSL**: Place nginx behind a TLS-terminating reverse proxy (Traefik, nginx, etc.)
4. **Firewall**: Only expose port `SENTRY_BIND` (default 9000) to the network
5. **Regular Updates**: Keep Sentry images updated with security patches
6. **Backups**: Regularly backup data volumes

## Production Recommendations

1. **Use Specific Image Versions**: Don't use `:nightly` tags in production

   ```env
   SENTRY_IMAGE=ghcr.io/getsentry/sentry:24.1.0
   ```

2. **Set Resource Limits**: Configure Docker resource limits for services

3. **Use External Database**: For large deployments, use managed PostgreSQL/ClickHouse

4. **Enable Monitoring**: Set up StatsD/Prometheus monitoring

5. **Configure Backups**: Automate volume backups

6. **Use a Reverse Proxy**: Add TLS termination with Let's Encrypt

7. **Scale Workers**: Add more worker containers for high-volume installations

## Differences from Official Install

This simplified deployment differs from the official installation:

- ✅ **Single compose file**: No multiple YAML files to manage
- ✅ **No install script**: Everything handled by Docker Compose
- ✅ **Volume-based config**: Configuration persists in volumes
- ✅ **Init container**: Setup runs automatically on first start
- ✅ **Production focused**: Optimized for deployment simplicity

## Support

For issues specific to this deployment setup, open an issue in this repository.

For general Sentry questions, see:

- [Sentry Documentation](https://docs.sentry.io/)
- [Self-Hosted Documentation](https://develop.sentry.dev/self-hosted/)
- [Community Forum](https://forum.sentry.io/)

## License

Same as Sentry self-hosted: BSL 1.1
