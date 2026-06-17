# 🐳 Docker Setup Guide - SRS-PLN-NPS

## 📋 Quick Start

### Option 1: Run All Services (Root docker-compose)
```bash
# From project root
cp .env.example .env.docker
docker-compose --env-file .env.docker up --build
```

### Option 2: Run Backend Only
```bash
cd backend
cp .env.example .env
docker-compose up --build
```

### Option 3: Run Admin Web Only
```bash
cd admin-web
cp .env.example .env.local
# Make sure backend is running at http://localhost:8080
docker-compose up --build
```

## 📁 Project Structure

```
.
├── docker-compose.yml          # Root: orchestrates all 3 services
├── .env.example                # Copy to .env.docker for root compose
│
├── backend/
│   ├── docker-compose.yml      # Backend + MySQL
│   ├── .env.example            # Backend environment variables
│   ├── Dockerfile              # Go build multi-stage
│   └── internal/database/migrations/
│
└── admin-web/
    ├── docker-compose.yml      # Next.js web app only
    ├── .env.example            # Admin web env vars
    └── Dockerfile              # Node.js multi-stage
```

## 🚀 Services Overview

| Service | Port | Technology | Container Name |
|---------|------|-----------|-----------------|
| **MySQL** | 3306 | MySQL 8.0 | pln_mysql |
| **Backend** | 8080 | Go 1.21 | pln_backend |
| **Admin Web** | 3000 | Node.js 18 + Next.js | pln_admin_web |

## 🔧 Environment Variables

### Root docker-compose.yml
```env
DB_NAME=bookify
DB_USER=bookify_user
DB_PASSWORD=bookify_secure_password
API_PORT=8080
WEB_PORT=3000
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
```

### backend/docker-compose.yml
```env
DB_HOST=db
DB_PORT=3306
JWT_SECRET=your-secret-key
PORT=8080
```

### admin-web/docker-compose.yml
```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
NODE_ENV=production
```

## 📍 Access Services

- **Backend API**: http://localhost:8080
  - Health: http://localhost:8080/api/rooms
  - Docs: Check `.graphql` or Postman

- **Admin Dashboard**: http://localhost:3000
  - Login required (superadmin)
  - Default: `superadmin@bookify.local` / `superadmin123`

- **MySQL**: localhost:3306
  - User: `bookify_user`
  - Password: `bookify_secure_password`
  - Database: `bookify`

## 📊 Database Management

### Access MySQL Container
```bash
docker exec -it pln_mysql mysql -u bookify_user -p bookify
# Password: bookify_secure_password
```

### View Database Logs
```bash
docker logs pln_mysql
```

### Seed Database
Migrations run automatically on startup from `backend/internal/database/migrations/`

## 🛑 Stop & Cleanup

### Stop All Services
```bash
docker-compose down
```

### Remove Everything (⚠️ Data Loss)
```bash
docker-compose down -v
```

### Remove Specific Service
```bash
docker-compose down pln_backend
```

## 🔍 Debugging

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f admin-web
docker-compose logs -f db
```

### Check Running Containers
```bash
docker ps
```

### Access Container Shell
```bash
docker exec -it pln_backend sh
docker exec -it pln_admin_web sh
docker exec -it pln_mysql bash
```

## ❤️ Health Checks

Each service has health checks configured:
- **Backend**: Checks `/api/rooms` endpoint every 30s
- **Admin Web**: Checks root path every 30s
- **MySQL**: Checks with `mysqladmin ping` every 10s

View health status:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## 🔐 Security Notes

⚠️ **IMPORTANT**: Change default credentials in production:

```env
DB_PASSWORD=your-strong-password
JWT_SECRET=your-very-long-random-secret-key
SUPERADMIN_PASSWORD=change-immediately
```

## 📦 Build Details

### Backend (Multi-stage)
1. **Builder stage**: Compile Go binary
2. **Runtime stage**: Minimal Alpine with binary only

### Admin Web (Multi-stage)
1. **Builder stage**: Install deps, build Next.js
2. **Production stage**: Install only prod deps, run Next.js

## 🐛 Troubleshooting

### "Cannot connect to backend"
- Ensure backend container is running: `docker ps`
- Check logs: `docker logs pln_backend`
- Verify network: `docker network ls`

### "Port already in use"
```bash
# Specify different port
docker-compose up -e API_PORT=8081 -e WEB_PORT=3001
```

### "Database connection refused"
- Wait for MySQL to be healthy (first startup takes ~30 seconds)
- Check: `docker inspect pln_mysql | grep-A5 Health`

### "Build fails"
```bash
# Clean rebuild
docker-compose down
docker system prune
docker-compose up --build
```

## ✅ Verification Checklist

After running `docker-compose up`:

- [ ] MySQL container is healthy: `docker ps | grep pln_mysql`
- [ ] Backend API responds: `curl http://localhost:8080/api/rooms`
- [ ] Admin dashboard loads: Open http://localhost:3000 in browser
- [ ] Login works with default credentials
- [ ] Can view dashboard with no errors

## 📚 References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/reference/)
- [Go Docker Best Practices](https://blog.golang.org/docker)
- [Next.js Docker Configuration](https://nextjs.org/docs/advanced-features/output-file-tracing)
