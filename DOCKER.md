# Docker Deployment Guide - PLN Room Booking System

## Overview
Panduan lengkap untuk menjalankan Sistem Booking Ruangan PLN menggunakan Docker.

## Prerequisites
- Docker (versi 20.10+)
- Docker Compose (versi 1.29+)
- Git

## Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd SRS_PLN-NPS
```

### 2. Setup Environment Variables
```bash
cp .env.docker .env.local
```

Edit `.env.local` sesuai kebutuhan Anda:
```bash
# Database credentials
DB_USER=pln_user
DB_PASSWORD=pln_password_anda

# JWT Secret (ganti dengan yang secure)
JWT_SECRET=your-super-secret-key-here

# API URL
NEXT_PUBLIC_API_URL=http://localhost:8080
```

### 3. Build dan Start Services
```bash
# Build all images
docker-compose build

# Start all services
docker-compose up -d

# Or both in one command
docker-compose up -d --build
```

### 4. Verify Services
```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Health check
curl http://localhost:8080/health
curl http://localhost:3000
```

## Services Architecture

```
        ┌───────────────────────────────┐
        │                               │
        ▼                               ▼
   ┌─────────┐                   ┌──────────┐
   │ Backend │                   │ Admin Web│
   │ (Go)    │                   │(Next.js) │
   │ :8080   │                   │ :3000    │
   └────┬────┘                   └──────────┘
        │
        ▼
   ┌─────────────┐
   │   MySQL DB  │
   │   :3306     │
   └─────────────┘
```

## Configuration Files

### Backend (Dockerfile)
- **Location**: `backend/Dockerfile`
- **Base Image**: `golang:1.21-alpine` (builder) → `alpine:latest` (runtime)
- **Port**: 8080
- **Features**: Multi-stage build, Health checks, CA certificates

### Admin Web (Dockerfile)
- **Location**: `admin-web/Dockerfile`
- **Base Image**: `node:18-alpine` (builder) → `node:18-alpine` (runtime)
- **Port**: 3000
- **Features**: Production optimized, dumb-init process manager

### Docker Compose
- **Location**: `docker-compose.yml`
- **Services**: MySQL, Backend, Admin Web
- **Networking**: Custom bridge network `pln_network`
- **Volumes**: Persistent MySQL data, uploads directory

## Commands Reference

### Start Services
```bash
# Start in background
docker-compose up -d

# Start with rebuild
docker-compose up -d --build

# Start with verbose logs
docker-compose up
```

### Stop Services
```bash
# Stop all services
docker-compose stop

# Stop specific service
docker-compose stop backend

# Stop and remove containers
docker-compose down

# Remove everything including volumes
docker-compose down -v
```

### View Logs
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs backend
docker-compose logs admin-web
docker-compose logs db

# Follow logs
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100 backend
```

### Execute Commands
```bash
# Connect to backend shell
docker-compose exec backend sh

# Run command in backend
docker-compose exec backend ls -la

# Connect to database
docker-compose exec db mysql -u pln_user -p pln_booking

# Run migrations (if applicable)
docker-compose exec backend ./server migrate up
```

### Database Management
```bash
# Backup database
docker-compose exec db mysqldump -u pln_user -p pln_booking > backup.sql

# Restore database
docker-compose exec -T db mysql -u pln_user -p pln_booking < backup.sql

# Access MySQL CLI
docker-compose exec db mysql -u pln_user -p pln_booking
```

## Environment Variables

### Database
- `DB_HOST`: Host database (default: db)
- `DB_PORT`: Port database (default: 3306)
- `DB_USER`: Username database
- `DB_PASSWORD`: Password database
- `DB_NAME`: Nama database
- `DB_ROOT_PASSWORD`: Root password MySQL

### Backend
- `API_PORT`: Port API (default: 8080)
- `JWT_SECRET`: Secret key untuk JWT token
- `UPLOAD_DIR`: Directory untuk upload files (default: /app/uploads)

### Frontend
- `NEXT_PUBLIC_API_URL`: URL API backend
- `NODE_ENV`: Environment (production/development)

## Troubleshooting

### Services tidak bisa terhubung
```bash
# Restart services
docker-compose restart

# Check network
docker network ls
docker network inspect srs_pln_nps_pln_network
```

### Database connection error
```bash
# Check MySQL is running
docker-compose ps db

# Check MySQL logs
docker-compose logs db

# Verify credentials
docker-compose exec db mysql -u pln_user -p pln_booking -e "SELECT 1"
```

### Port conflict
```bash
# Change port di docker-compose.yml atau gunakan:
docker-compose down
# Edit docker-compose.yml
docker-compose up -d
```

### Memory/Resource issues
```bash
# Check Docker resources
docker stats

# Limit resource di docker-compose.yml:
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
```

## Production Deployment

Untuk production deployment dengan SSL/TLS, gunakan reverse proxy seperti Nginx atau Traefik di luar Docker container ini.

### Update Environment untuk Production
```bash
# Edit .env.local
DB_PASSWORD=secure-password-production
JWT_SECRET=production-secret-key
NEXT_PUBLIC_API_URL=https://api.yourdomain.com
```

### Performance Optimization
```bash
# docker-compose.yml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
  admin-web:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
```

### Backup & Restore
```bash
# Backup entire system
docker-compose exec db mysqldump -u pln_user -p pln_booking > backup_$(date +%Y%m%d).sql

# Backup volumes
docker run --rm -v srs_pln_nps_mysql_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/mysql_backup.tar.gz /data
```

## Monitoring

### Health Checks
```bash
# Backend health
curl http://localhost:8080/health

# Admin Web health
curl http://localhost:3000

# Database health
docker-compose exec db mysqladmin ping -u pln_user -p
```

### Logs Monitoring
```bash
# Real-time logs
docker-compose logs -f

# Filter by service
docker-compose logs -f backend | grep "ERROR"
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Go Docker Best Practices](https://golang.org/doc/tutorial/run-tests-github)
- [Next.js Docker Documentation](https://nextjs.org/docs/deployment/docker)

## Support

Untuk pertanyaan atau issues, silakan buat issue di repository.

---

**Last Updated**: May 22, 2026
