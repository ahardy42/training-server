# Docker Deployment Guide

This guide covers deploying the Training Server application using Docker, including deployment to a Raspberry Pi.

## Quick Start: Raspberry Pi Deployment

1. **Install Docker**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

2. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd training-server
   ```

3. **Create `.env` file**:
   ```bash
   nano .env
   ```
   Add:
   ```bash
   TRAINING_SERVER_DATABASE_PASSWORD=your_secure_password_here
   RAILS_MASTER_KEY=your_32_character_key_from_config_master_key
   ```
   Get your Rails master key: `cat config/master.key` (on your dev machine)

4. **Build and start**:
   ```bash
   docker-compose -f docker-compose.prod.yml build
   docker-compose -f docker-compose.prod.yml up -d
   ```

5. **Access**: Open `http://your-raspberry-pi-ip` in your browser

The application automatically creates the database, runs migrations, and starts the web server on port 80.

## Prerequisites

### On Raspberry Pi
- Raspberry Pi OS (or compatible Linux distribution)
- Docker installed
- Docker Compose plugin installed
- Redis installed and running (required for Sidekiq background jobs)
- At least 2GB RAM recommended (4GB+ for better performance)

### Redis Installation

Redis is required for Sidekiq background job processing. Install Redis on your system:

**On Raspberry Pi / Ubuntu / Debian:**
```bash
sudo apt-get update
sudo apt-get install redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

**On macOS:**
```bash
brew install redis
brew services start redis
```

**Verify Redis is running:**
```bash
redis-cli ping
# Should return: PONG
```

**For Docker deployments**, you'll need to add a Redis service to your `docker-compose.prod.yml`:
```yaml
redis:
  image: redis:7-alpine
  container_name: training_server_redis
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  networks:
    - training_server_network
  restart: unless-stopped
```

And add the Redis URL to your web service environment:
```yaml
REDIS_URL: redis://redis:6379/0
```

Don't forget to add `redis_data` to your volumes section.

## Local Development with Docker

1. **Set up environment variables**:
   Create a `.env` file:
   ```bash
   POSTGRES_PASSWORD=training_server_dev
   RAILS_MASTER_KEY=$(cat config/master.key)
   ```

2. **Start services**:
   ```bash
   docker-compose up -d
   rake docker:setup_db
   ```

3. **Access**: http://localhost:3000

## Production Deployment

### Setup Steps

1. **Install Docker and Docker Compose**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker $USER
   sudo apt-get install docker-compose-plugin
   # Log out and back in
   ```

2. **Clone repository**:
   ```bash
   git clone <repository-url>
   cd training-server
   ```

3. **Create `.env` file**:
   ```bash
   TRAINING_SERVER_DATABASE_PASSWORD=your_secure_password_here
   RAILS_MASTER_KEY=your_rails_master_key_from_config_master_key
   ```

4. **Build and start**:
   ```bash
   docker-compose -f docker-compose.prod.yml build
   docker-compose -f docker-compose.prod.yml up -d
   ```

5. **Verify**:
   ```bash
   docker-compose -f docker-compose.prod.yml ps
   curl http://localhost:80
   ```

**Note**: Migrations run automatically on container start via the docker-entrypoint script.

## Exposing to the Internet

### Cloudflare Tunnel (Recommended)

**Install cloudflared:**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

**Set up as systemd service:**

1. Create service file:
   ```bash
   sudo nano /etc/systemd/system/cloudflared.service
   ```

2. Add configuration (replace `YOUR_USERNAME` and `YOUR_TUNNEL_NAME`):
   ```ini
   [Unit]
   Description=Cloudflare Tunnel
   After=network.target docker.service
   Requires=docker.service

   [Service]
   Type=simple
   User=YOUR_USERNAME
   Group=YOUR_USERNAME
   ExecStart=/usr/local/bin/cloudflared tunnel run --url http://localhost:80 YOUR_TUNNEL_NAME
   Restart=on-failure
   RestartSec=15s
   WorkingDirectory=/home/YOUR_USERNAME
   Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

   [Install]
   WantedBy=multi-user.target
   ```

3. Enable and start:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable cloudflared
   sudo systemctl start cloudflared
   sudo systemctl status cloudflared
   ```

**Verify localhost:80 is listening:**
```bash
curl -I http://localhost:80
ss -tlnp | grep :80
```

**Quick testing (without systemd):**
```bash
# Using screen
screen -S cloudflared
cloudflared tunnel run --url http://localhost:80 YOUR_TUNNEL_NAME
# Ctrl+A then D to detach

# Or using tmux
tmux new -s cloudflared
cloudflared tunnel run --url http://localhost:80 YOUR_TUNNEL_NAME
# Ctrl+B then D to detach
```

**Important**: Use port `80` (not 3000) - Docker maps container port 80 to host port 80.

### Port Forwarding + Nginx (Alternative)

1. Set up port forwarding on your router
2. Install Nginx:
   ```bash
   sudo apt-get install nginx certbot python3-certbot-nginx
   ```
3. Configure Nginx to proxy to `http://localhost:80`
4. Set up SSL with Let's Encrypt

## Rake Tasks

Run `rake -T docker` to see all available tasks:

**Development:**
- `rake docker:build_dev` - Build development image
- `rake docker:start_dev` - Start development environment
- `rake docker:stop_dev` - Stop development environment
- `rake docker:setup_db` - Set up development database
- `rake docker:logs_dev` - View development logs
- `rake docker:console_dev` - Open Rails console

**Production:**
- `rake docker:build_prod` - Build production image
- `rake docker:start_prod` - Start production environment
- `rake docker:stop_prod` - Stop production environment
- `rake docker:logs_prod` - View production logs
- `rake docker:console_prod` - Open Rails console

## Docker Compose Commands

**Common operations:**
```bash
# Start services
docker-compose -f docker-compose.prod.yml up -d

# Stop services
docker-compose -f docker-compose.prod.yml down

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart services
docker-compose -f docker-compose.prod.yml restart

# Access Rails console
docker-compose -f docker-compose.prod.yml exec web bin/rails console

# Run migrations
docker-compose -f docker-compose.prod.yml exec web bin/rails db:migrate

# Check status
docker-compose -f docker-compose.prod.yml ps
```

## Environment Variables

**Required:**
- `RAILS_MASTER_KEY`: Rails master key (from `config/master.key`)
- `TRAINING_SERVER_DATABASE_PASSWORD`: PostgreSQL password for production

**Optional:**
- `POSTGRES_PASSWORD`: PostgreSQL password for development (defaults to `training_server_dev`)
- `RAILS_LOG_LEVEL`: Log level (default: `info`)
- `RAILS_MAX_THREADS`: Database connection pool size (default: 5)
- `REDIS_URL`: Redis connection URL (defaults to `redis://localhost:6379/0`)

**Note**: If using Docker, set `REDIS_URL=redis://redis:6379/0` to connect to the Redis container.

## Troubleshooting

### Docker Permission Denied

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Exec Format Error (Architecture Mismatch)

The `docker-compose.prod.yml` includes `platform: linux/arm64` for ARM support. If issues persist:

```bash
# Verify architecture
uname -m

# Pull correct ARM image
docker pull --platform linux/arm64 kartoza/postgis:16-3.4
```

### Cloudflare Tunnel Error 1033

The tunnel can't reach your local service. Verify:

```bash
# Check containers are running
docker-compose -f docker-compose.prod.yml ps

# Test localhost:80
curl -v http://localhost:80

# Check tunnel logs
sudo journalctl -u cloudflared -n 50
```

### Database Connection Issues

```bash
# Check container status
docker-compose -f docker-compose.prod.yml ps

# Check logs
docker-compose -f docker-compose.prod.yml logs db

# Verify environment variables
docker-compose -f docker-compose.prod.yml exec web env | grep POSTGRES
```

### Redis Connection Issues

If background jobs aren't processing:

```bash
# Verify Redis is running
redis-cli ping
# Should return: PONG

# Check Redis logs (if using Docker)
docker-compose -f docker-compose.prod.yml logs redis

# Verify Sidekiq can connect
docker-compose -f docker-compose.prod.yml exec web bundle exec sidekiq
# Or check Sidekiq web UI at http://your-server/sidekiq
```

**For Docker deployments**, ensure:
1. Redis service is added to `docker-compose.prod.yml`
2. `REDIS_URL` environment variable is set correctly
3. Web service depends on Redis service

### Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :80

# Or change port in docker-compose.prod.yml
ports:
  - "8080:80"
```

## Backup and Restore

**Backup database:**
```bash
docker-compose -f docker-compose.prod.yml exec db pg_dump -U training_server training_server_production > backup_$(date +%Y%m%d).sql
```

**Restore database:**
```bash
docker-compose -f docker-compose.prod.yml exec -T db psql -U training_server training_server_production < backup_YYYYMMDD.sql
```

## Security Considerations

1. Use strong, unique passwords
2. Never commit `.env` files or `config/master.key` to Git
3. Use HTTPS/SSL in production
4. Keep Docker images and system packages updated
5. Regularly backup your database and storage files
