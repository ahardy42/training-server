# Docker Deployment Guide

This guide covers deploying the Training Server application using Docker, including deployment to a Raspberry Pi.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development with Docker](#local-development-with-docker)
- [Building for Raspberry Pi](#building-for-raspberry-pi)
- [Production Deployment](#production-deployment)
- [Rake Tasks](#rake-tasks)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### On Your Development Machine

- Docker Desktop (or Docker Engine) installed
- Docker Compose v2 (included with Docker Desktop)
- Git

### On Raspberry Pi

- Raspberry Pi OS (or compatible Linux distribution)
- Docker installed: `curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh`
- Docker Compose installed: `sudo apt-get install docker-compose-plugin`
- At least 2GB RAM recommended (4GB+ for better performance)
- Sufficient storage for PostgreSQL data and application files

## Local Development with Docker

### Quick Start

1. **Clone the repository** (if you haven't already):
   ```bash
   git clone <repository-url>
   cd training-server
   ```

2. **Set up environment variables**:
   Create a `.env` file in the project root:
   ```bash
   POSTGRES_PASSWORD=training_server_dev
   RAILS_MASTER_KEY=$(cat config/master.key)
   ```

3. **Start the services**:
   ```bash
   rake docker:start_dev
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose up -d
   ```

4. **Set up the database**:
   ```bash
   rake docker:setup_db
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose exec web bin/rails db:create
   docker-compose exec web bin/rails db:migrate
   ```

5. **Access the application**:
   Open http://localhost:3000 in your browser

### Development Workflow

Using Rake tasks (recommended):
- **View logs**: `rake docker:logs_dev`
- **Run Rails console**: `rake docker:console_dev`
- **Run database console**: `docker-compose exec web bin/rails dbconsole`
- **Run migrations**: `docker-compose exec web bin/rails db:migrate`
- **Stop services**: `rake docker:stop_dev`
- **Stop and remove volumes** (⚠️ deletes data): `docker-compose down -v`

Or using docker-compose directly:
- **View logs**: `docker-compose logs -f web`
- **Run Rails console**: `docker-compose exec web bin/rails console`
- **Run database console**: `docker-compose exec web bin/rails dbconsole`
- **Run migrations**: `docker-compose exec web bin/rails db:migrate`
- **Stop services**: `docker-compose down`

### Rebuilding After Changes

If you change Gemfile or Dockerfile:
```bash
docker-compose build
docker-compose up -d
```

## Building for Raspberry Pi

### Option 1: Build on Raspberry Pi (Recommended)

The simplest approach is to build directly on your Raspberry Pi:

1. **Transfer your code to Raspberry Pi**:
   ```bash
   # On your development machine
   rsync -avz --exclude 'node_modules' --exclude '.git' \
     ./ pi@raspberry-pi-ip:/home/pi/training-server/
   ```

   Or use Git:
   ```bash
   # On Raspberry Pi
   git clone <repository-url>
   cd training-server
   ```

2. **Build and run on Raspberry Pi**:
   ```bash
   # On Raspberry Pi
   rake docker:build_raspberry_pi
   rake docker:start_prod
   rake docker:setup_db_prod
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose -f docker-compose.prod.yml build
   docker-compose -f docker-compose.prod.yml up -d
   ```

### Option 2: Cross-Platform Build (Advanced)

Build ARM images on your development machine using Docker Buildx:

1. **Set up buildx** (if not already set up):
   ```bash
   docker buildx create --name multiarch --use
   docker buildx inspect --bootstrap
   ```

2. **Build for ARM64**:
   ```bash
   docker buildx build --platform linux/arm64 -t training_server:arm64 .
   ```

3. **Save and transfer image**:
   ```bash
   docker save training_server:arm64 | gzip > training_server_arm64.tar.gz
   # Transfer to Raspberry Pi, then:
   # docker load < training_server_arm64.tar.gz
   ```

## Production Deployment

### Initial Setup on Raspberry Pi

1. **Install Docker and Docker Compose** (if not already installed):
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker $USER
   # Log out and back in for group changes to take effect
   ```

2. **Clone or transfer your code**:
   ```bash
   git clone <repository-url>
   cd training-server
   ```

3. **Create production environment file**:
   Create a `.env` file:
   ```bash
   TRAINING_SERVER_DATABASE_PASSWORD=your_secure_password_here
   RAILS_MASTER_KEY=your_rails_master_key_here
   ```

   **Important**: Generate a strong password for the database and keep your `RAILS_MASTER_KEY` secure!

4. **Build the production image**:
   ```bash
   rake docker:build_prod
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose -f docker-compose.prod.yml build
   ```

5. **Start the services**:
   ```bash
   rake docker:start_prod
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

6. **Set up the database**:
   ```bash
   rake docker:setup_db_prod
   ```

   Or using docker-compose directly:
   ```bash
   docker-compose -f docker-compose.prod.yml exec web bin/rails db:create
   docker-compose -f docker-compose.prod.yml exec web bin/rails db:migrate
   ```

7. **Create an admin user** (optional):
   ```bash
   docker-compose -f docker-compose.prod.yml exec web bin/rails console
   # Then in the console:
   # User.create!(email: 'admin@example.com', password: 'secure_password')
   ```

### Exposing to the Internet

To access your application from anywhere, you'll need to:

1. **Set up port forwarding on your router**:
   - Forward external port 80 (or another port) to your Raspberry Pi's IP on port 80
   - Or use a reverse proxy like Nginx (recommended for production)

2. **Configure a reverse proxy with Nginx** (Recommended):
   
   Install Nginx on Raspberry Pi:
   ```bash
   sudo apt-get update
   sudo apt-get install nginx certbot python3-certbot-nginx
   ```

   Create `/etc/nginx/sites-available/training-server`:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://localhost:80;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

   Enable the site:
   ```bash
   sudo ln -s /etc/nginx/sites-available/training-server /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **Set up SSL with Let's Encrypt**:
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

4. **Update Rails configuration**:
   Update `config/environments/production.rb` to set the correct host:
   ```ruby
   config.hosts << "your-domain.com"
   config.action_mailer.default_url_options = { host: "your-domain.com" }
   ```

### Managing the Production Deployment

Using Rake tasks (recommended):
- **View logs**: `rake docker:logs_prod`
- **Open Rails console**: `rake docker:console_prod`
- **Stop services**: `rake docker:stop_prod`
- **Update application**:
  ```bash
  git pull
  rake docker:build_prod
  rake docker:start_prod
  docker-compose -f docker-compose.prod.yml exec web bin/rails db:migrate
  ```

Or using docker-compose directly:
- **View logs**: `docker-compose -f docker-compose.prod.yml logs -f`
- **Restart services**: `docker-compose -f docker-compose.prod.yml restart`
- **Stop services**: `docker-compose -f docker-compose.prod.yml down`
- **Update application**:
  ```bash
  git pull
  docker-compose -f docker-compose.prod.yml build
  docker-compose -f docker-compose.prod.yml up -d
  docker-compose -f docker-compose.prod.yml exec web bin/rails db:migrate
  ```

### Backup and Restore

**Backup database**:
```bash
docker-compose -f docker-compose.prod.yml exec db pg_dump -U training_server training_server_production > backup_$(date +%Y%m%d).sql
```

**Restore database**:
```bash
docker-compose -f docker-compose.prod.yml exec -T db psql -U training_server training_server_production < backup_20240101.sql
```

**Backup storage files**:
```bash
docker run --rm -v training_server_storage_data:/data -v $(pwd):/backup alpine tar czf /backup/storage_backup_$(date +%Y%m%d).tar.gz /data
```

## Rake Tasks

This project includes Rake tasks for common Docker operations. Run `rake -T docker` to see all available tasks:

### Development Tasks
- `rake docker:build_dev` - Build development Docker image
- `rake docker:start_dev` - Start development environment
- `rake docker:stop_dev` - Stop development environment
- `rake docker:setup_db` - Set up development database
- `rake docker:logs_dev` - View development logs
- `rake docker:console_dev` - Open Rails console in development

### Production Tasks
- `rake docker:build_prod` - Build production Docker image
- `rake docker:build_raspberry_pi` - Build production image for Raspberry Pi (ARM)
- `rake docker:start_prod` - Start production environment
- `rake docker:stop_prod` - Stop production environment
- `rake docker:setup_db_prod` - Set up production database
- `rake docker:logs_prod` - View production logs
- `rake docker:console_prod` - Open Rails console in production

## Environment Variables

### Required Variables

- `RAILS_MASTER_KEY`: Rails master key (found in `config/master.key`)
- `TRAINING_SERVER_DATABASE_PASSWORD`: PostgreSQL password for production

### Optional Variables

- `POSTGRES_PASSWORD`: PostgreSQL password for development (defaults to `training_server_dev`)
- `RAILS_LOG_LEVEL`: Log level (default: `info`)
- `RAILS_MAX_THREADS`: Maximum database connection pool size (default: 5)

## Troubleshooting

### Database Connection Issues

If you see database connection errors:

1. **Check if database is running**:
   ```bash
   docker-compose ps
   ```

2. **Check database logs**:
   ```bash
   docker-compose logs db
   ```

3. **Verify environment variables**:
   ```bash
   docker-compose exec web env | grep POSTGRES
   ```

### Port Already in Use

If port 80 or 3000 is already in use:

1. **Find what's using the port**:
   ```bash
   sudo lsof -i :80
   ```

2. **Change the port in docker-compose.yml**:
   ```yaml
   ports:
     - "8080:80"  # Use port 8080 instead
   ```

### Out of Memory on Raspberry Pi

If you encounter memory issues:

1. **Increase swap space**:
   ```bash
   sudo dphys-swapfile swapoff
   sudo nano /etc/dphys-swapfile
   # Change CONF_SWAPSIZE=100 to CONF_SWAPSIZE=2048
   sudo dphys-swapfile setup
   sudo dphys-swapfile swapon
   ```

2. **Limit Docker memory** (in docker-compose.prod.yml):
   ```yaml
   web:
     deploy:
       resources:
         limits:
           memory: 1G
   ```

### Build Fails on Raspberry Pi

If builds are slow or fail:

1. **Use a faster SD card** (Class 10 or better recommended)
2. **Build during off-peak hours**
3. **Consider building on a more powerful machine and transferring the image**

### PostGIS Extension Errors

If you see PostGIS-related errors:

1. **Verify PostGIS is available in the database**:
   ```bash
   docker-compose exec db psql -U training_server -d training_server_production -c "SELECT PostGIS_version();"
   ```

2. **Manually enable PostGIS if needed**:
   ```bash
   docker-compose exec db psql -U training_server -d training_server_production -c "CREATE EXTENSION IF NOT EXISTS postgis;"
   ```

## Security Considerations

1. **Change default passwords**: Always use strong, unique passwords
2. **Keep secrets secure**: Never commit `.env` files or `config/master.key` to Git
3. **Use HTTPS**: Always use SSL/TLS in production (Let's Encrypt is free)
4. **Firewall**: Configure your router's firewall to only expose necessary ports
5. **Regular updates**: Keep Docker images and system packages updated
6. **Backups**: Regularly backup your database and storage files

## Next Steps

- Set up automated backups
- Configure monitoring and alerting
- Set up CI/CD for automated deployments
- Consider using Kamal for more advanced deployment scenarios

