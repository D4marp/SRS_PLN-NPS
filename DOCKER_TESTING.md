# 🐳 Docker Infrastructure - Testing Plan

## ✅ Completed Setup

### 1. **Root docker-compose.yml** (Orchestrator)
- ✅ MySQL 8.0 service
- ✅ Backend Go service (depends_on: db healthy)
- ✅ Admin Web Next.js service (depends_on: backend)
- ✅ Network: `pln_network`
- ✅ Health checks for all services
- ✅ Environment variables management

### 2. **backend/docker-compose.yml** (Standalone)
- ✅ MySQL 8.0 service
- ✅ Go Backend API service
- ✅ Network: `backend_network`
- ✅ Health check: GET /api/rooms
- ✅ Volumes: uploads directory
- ✅ Auto-runs migrations from `/migrations`

### 3. **admin-web/docker-compose.yml** (Standalone)
- ✅ Next.js web app
- ✅ Health check: GET / (port 3000)
- ✅ Env: NEXT_PUBLIC_API_BASE_URL
- ✅ Production build with optimized staging

### 4. **Environment Files**
- ✅ `.env.example` (root) - for docker-compose
- ✅ `backend/.env.example` - for backend config
- ✅ `backend/.env.docker` - auto-created for Docker
- ✅ `admin-web/.env.example` - for admin-web config
- ✅ Documentation in DOCKER_USAGE.md

### 5. **Dockerfiles**
- ✅ `backend/Dockerfile` - Multi-stage Go build
- ✅ `admin-web/Dockerfile` - Multi-stage Node/Next.js build

## 🧪 Testing Steps (When Docker Daemon is Running)

### Test Backend Only
```bash
cd backend
docker-compose -f docker-compose.yml --env-file .env.docker up --build

# In another terminal after services are healthy (~30s):
curl http://localhost:8080/api/rooms
curl http://localhost:8080/api/facilities

# Verify database is running:
docker exec -it pln_mysql mysql -u bookify_user -p bookify -e "SHOW TABLES;"
```

### Test Admin Web Only
```bash
# Requires backend running first on localhost:8080

cd admin-web
docker-compose -f docker-compose.yml up --build

# Access: http://localhost:3000
# Login: superadmin@bookify.local / superadmin123
```

### Test All Together (Root)
```bash
# From project root
cp .env.example .env.docker
docker-compose -f docker-compose.yml --env-file .env.docker up --build

# Wait for all services to be healthy (check "docker ps --format")
# Then test:
curl http://localhost:8080/api/rooms          # Backend
curl http://localhost:3000                     # Admin Web
mysql -h localhost -u bookify_user -p bookify # Database
```

## 📊 Expected Results

### When All Services Are Healthy:

**Backend Container (`pln_backend`)**
```
Status: Up X minutes
Health: (healthy)
Logs should show:
  - "Connecting to database..."
  - "Running migrations..."
  - "Server listening on :8080"
```

**Admin Web Container (`pln_admin_web`)**
```
Status: Up X minutes  
Health: (healthy)
Logs should show:
  - "started server on 0.0.0.0:3000"
  - No build errors
```

**MySQL Container (`pln_mysql`)**
```
Status: Up X minutes
Health: (healthy)
Database ready for connections
```

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│         docker-compose.yml (Root)                    │
│  • Orchestrates all 3 services                       │
│  • Shared pln_network                               │
│  • Shared mysql_data volume                         │
└─────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌────────┐         ┌──────────┐         ┌─────────────┐
    │ MySQL  │         │ Backend  │         │ Admin Web   │
    │ 3306   │◄────────│ 8080     │◄────────│ 3000        │
    │ pln_mysql        │ pln_backend       │ pln_admin_web
    └────────┘         └──────────┘         └─────────────┘
    (Shared DB)     (Go + Migrations)   (Next.js App)

    Each folder has standalone docker-compose.yml for independent testing
```

## 📋 Verification Checklist for Testing

- [ ] Docker daemon is running (`docker --version` works)
- [ ] All 3 images build successfully (`docker images | grep pln`)
- [ ] Containers start in correct order (db → backend → web)
- [ ] MySQL accepts connections after health check passes
- [ ] Backend migrations run automatically
- [ ] Backend API responds to GET /api/rooms
- [ ] Admin Web loads without errors
- [ ] Admin Web can login with superadmin credentials
- [ ] Admin Web can access Dashboard and Facilities pages
- [ ] Health checks all pass after startup

## 🔧 Troubleshooting Guide

### Docker Daemon Not Running
**Solution**: 
- Start Docker Desktop, OR
- If using Colima: `colima start`

### Port Already in Use
**Solution**:
```bash
# Use different ports
docker-compose up -e API_PORT=8081 -e WEB_PORT=3001
```

### Database Migration Fails
**Solution**:
```bash
# Check logs
docker logs pln_mysql
# Verify migration files exist
ls backend/internal/database/migrations/
```

### Backend Can't Connect to Database
**Solution**:
```bash
# Verify db container is healthy
docker ps | grep pln_mysql
# Check if hostname resolves
docker exec pln_backend getent hosts db
```

## 📦 Next Steps After Docker Testing

1. Test with actual Docker Desktop / Colima running
2. Deploy to staging environment
3. Setup CI/CD pipeline to build images automatically
4. Consider Docker registries (Docker Hub, GitHub Container Registry)
5. Optimize image sizes (especially Go and Next.js images)
6. Add docker-compose.prod.yml for production deployment

## 📚 Resources

- Docker Compose Docs: https://docs.docker.com/compose/
- Colima (Docker on Mac): https://github.com/abiosoft/colima
- Go Docker Image: https://hub.docker.com/_/golang
- Node.js Docker Image: https://hub.docker.com/_/node
