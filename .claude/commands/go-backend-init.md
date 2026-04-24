# Go Backend Init

Inisialisasi project Go backend untuk menggantikan Firebase pada aplikasi Bookify Rooms.

## Context Aplikasi

Aplikasi Flutter **Bookify Rooms** saat ini menggunakan:
- Firebase Auth (email/password)
- Cloud Firestore (collections: users, rooms, bookings)
- Firebase Storage (room images di `room_images/`)

Go backend akan menggantikan semua layanan Firebase tersebut.

## Role Hierarchy

```
superadmin  →  Kelola semua user, promosi/demosi admin, akses semua fitur
admin       →  Approve/reject booking, kelola ruangan (add/edit/delete)
booking     →  Role untuk petugas booking desk / kiosk mode
user        →  Regular user, bisa buat dan cancel booking sendiri
```

## Booking Status Flow (dengan approval layer)

```
User buat booking
      ↓
  [pending]   ← status awal semua booking baru
      ↓
Admin review booking
      ├── approve → [confirmed]
      └── reject  → [rejected]  (+ rejection_reason)
              ↓
[confirmed] → user/admin cancel → [cancelled]
[confirmed] → admin mark done  → [completed]
```

## Tugas

Buat struktur project Go backend lengkap dengan layout berikut:

```
backend/
├── cmd/
│   └── server/
│       └── main.go          # Entry point
├── internal/
│   ├── config/
│   │   └── config.go        # Load env vars
│   ├── database/
│   │   ├── postgres.go      # DB connection pool
│   │   └── migrations/      # SQL migration files
│   │       ├── 001_create_users.sql
│   │       ├── 002_create_rooms.sql
│   │       ├── 003_create_bookings.sql
│   │       └── 004_create_booking_history.sql
│   ├── middleware/
│   │   ├── auth.go          # JWT auth middleware
│   │   └── cors.go          # CORS middleware
│   ├── handlers/            # HTTP handlers (dibuat di skill lain)
│   ├── models/              # Go structs (dibuat di skill lain)
│   ├── repository/          # DB queries layer
│   └── utils/
│       ├── jwt.go           # JWT generate/verify
│       ├── password.go      # bcrypt hash/verify
│       └── response.go      # Standard JSON response helpers
├── uploads/                 # Local file storage untuk dev
├── .env.example
├── .env
├── go.mod
├── go.sum
└── Makefile
```

## Langkah-langkah

### 1. Inisialisasi Go module

```bash
mkdir -p backend
cd backend
go mod init github.com/bookify-rooms/backend
```

### 2. Install dependencies

```bash
go get github.com/gin-gonic/gin@latest          # HTTP framework
go get github.com/jackc/pgx/v5@latest           # PostgreSQL driver
go get github.com/golang-jwt/jwt/v5@latest      # JWT
go get golang.org/x/crypto@latest               # bcrypt
go get github.com/google/uuid@latest            # UUID generation
go get github.com/joho/godotenv@latest          # .env loading
go get github.com/rs/cors@latest                # CORS
go get github.com/golang-migrate/migrate/v4@latest  # DB migrations
```

### 3. Buat semua file

Buat setiap file sesuai spesifikasi berikut:

#### `cmd/server/main.go`

```go
package main

import (
    "log"
    "github.com/bookify-rooms/backend/internal/config"
    "github.com/bookify-rooms/backend/internal/database"
    "github.com/bookify-rooms/backend/internal/server"
)

func main() {
    cfg := config.Load()

    db, err := database.Connect(cfg.DatabaseURL)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    if err := database.RunMigrations(cfg.DatabaseURL); err != nil {
        log.Fatalf("Failed to run migrations: %v", err)
    }

    srv := server.New(cfg, db)
    log.Printf("Server starting on port %s", cfg.Port)
    if err := srv.Run(); err != nil {
        log.Fatalf("Server error: %v", err)
    }
}
```

#### `internal/config/config.go`

```go
package config

import (
    "log"
    "os"
    "github.com/joho/godotenv"
)

type Config struct {
    Port           string
    DatabaseURL    string
    JWTSecret      string
    JWTExpiry      string  // e.g. "24h"
    UploadsDir     string
    MaxUploadSize  int64   // bytes
    AllowedOrigins []string
}

func Load() *Config {
    if err := godotenv.Load(); err != nil {
        log.Println("No .env file found, using environment variables")
    }

    return &Config{
        Port:          getEnv("PORT", "8080"),
        DatabaseURL:   getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/bookify?sslmode=disable"),
        JWTSecret:     getEnv("JWT_SECRET", "change-this-secret-in-production"),
        JWTExpiry:     getEnv("JWT_EXPIRY", "168h"), // 7 days
        UploadsDir:    getEnv("UPLOADS_DIR", "./uploads"),
        AllowedOrigins: []string{getEnv("ALLOWED_ORIGINS", "*")},
    }
}

func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}
```

#### `internal/database/postgres.go`

```go
package database

import (
    "context"
    "github.com/jackc/pgx/v5/pgxpool"
)

func Connect(databaseURL string) (*pgxpool.Pool, error) {
    pool, err := pgxpool.New(context.Background(), databaseURL)
    if err != nil {
        return nil, err
    }
    if err := pool.Ping(context.Background()); err != nil {
        return nil, err
    }
    return pool, nil
}
```

#### `internal/database/migrations/001_create_users.sql`

```sql
-- Role hierarchy: superadmin > admin > booking > user
CREATE TABLE IF NOT EXISTS users (
    id            VARCHAR(36) PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password      VARCHAR(255) NOT NULL,
    profile_image VARCHAR(500),
    city          VARCHAR(100),
    role          VARCHAR(20) NOT NULL DEFAULT 'user'
                  CHECK (role IN ('user', 'admin', 'booking', 'superadmin')),
    created_at    BIGINT NOT NULL,
    updated_at    BIGINT
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
```

#### `internal/database/migrations/002_create_rooms.sql`

```sql
CREATE TABLE IF NOT EXISTS rooms (
    id              VARCHAR(36) PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT NOT NULL,
    location        VARCHAR(500) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    room_class      VARCHAR(100) NOT NULL,
    image_urls      TEXT[] DEFAULT '{}',
    amenities       TEXT[] DEFAULT '{}',
    has_ac          BOOLEAN NOT NULL DEFAULT false,
    is_available    BOOLEAN NOT NULL DEFAULT true,
    max_guests      INTEGER NOT NULL,
    contact_number  VARCHAR(50) NOT NULL,
    floor           VARCHAR(50),
    building        VARCHAR(100),
    created_at      BIGINT NOT NULL,
    updated_at      BIGINT
);

CREATE INDEX IF NOT EXISTS idx_rooms_city ON rooms(city);
CREATE INDEX IF NOT EXISTS idx_rooms_is_available ON rooms(is_available);
CREATE INDEX IF NOT EXISTS idx_rooms_room_class ON rooms(room_class);
```

#### `internal/database/migrations/003_create_bookings.sql`

```sql
-- Status flow: pending → confirmed (approved) | rejected → cancelled | completed
CREATE TABLE IF NOT EXISTS bookings (
    id               VARCHAR(36) PRIMARY KEY,
    user_id          VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id          VARCHAR(36) NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    booking_date     BIGINT NOT NULL,
    check_in_time    VARCHAR(5) NOT NULL,
    check_out_time   VARCHAR(5) NOT NULL,
    number_of_guests INTEGER NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','confirmed','rejected','cancelled','completed')),
    purpose          TEXT,
    rejection_reason TEXT,              -- diisi saat admin reject
    approved_by      VARCHAR(36),       -- user_id admin yang approve/reject
    approved_at      BIGINT,            -- timestamp approve/reject
    room_name        VARCHAR(255),
    room_location    VARCHAR(500),
    room_image_url   VARCHAR(500),
    user_name        VARCHAR(255),
    user_email       VARCHAR(255),
    created_at       BIGINT NOT NULL,
    updated_at       BIGINT
);

CREATE INDEX IF NOT EXISTS idx_bookings_user_id    ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_room_id    ON bookings(room_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status     ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date ON bookings(booking_date);
-- Index untuk admin melihat pending bookings
CREATE INDEX IF NOT EXISTS idx_bookings_pending    ON bookings(status) WHERE status = 'pending';
```

#### `internal/database/migrations/004_create_booking_history.sql`

```sql
-- Audit trail: setiap perubahan status booking dicatat di sini
CREATE TABLE IF NOT EXISTS booking_status_history (
    id          VARCHAR(36) PRIMARY KEY,
    booking_id  VARCHAR(36) NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    from_status VARCHAR(20) NOT NULL,
    to_status   VARCHAR(20) NOT NULL,
    changed_by  VARCHAR(36) NOT NULL REFERENCES users(id),
    note        TEXT,
    created_at  BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_booking_history_booking_id ON booking_status_history(booking_id);
```

#### `internal/utils/response.go`

```go
package utils

import (
    "github.com/gin-gonic/gin"
)

type APIResponse struct {
    Success bool        `json:"success"`
    Message string      `json:"message,omitempty"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
}

func Success(c *gin.Context, statusCode int, data interface{}) {
    c.JSON(statusCode, APIResponse{Success: true, Data: data})
}

func SuccessMessage(c *gin.Context, statusCode int, message string, data interface{}) {
    c.JSON(statusCode, APIResponse{Success: true, Message: message, Data: data})
}

func Error(c *gin.Context, statusCode int, message string) {
    c.JSON(statusCode, APIResponse{Success: false, Error: message})
}
```

#### `internal/utils/password.go`

```go
package utils

import "golang.org/x/crypto/bcrypt"

func HashPassword(password string) (string, error) {
    bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    return string(bytes), err
}

func CheckPassword(password, hash string) bool {
    return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
```

#### `internal/utils/jwt.go`

```go
package utils

import (
    "errors"
    "time"
    "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
    UserID string `json:"user_id"`
    Role   string `json:"role"`
    jwt.RegisteredClaims
}

func GenerateToken(userID, role, secret, expiry string) (string, error) {
    duration, err := time.ParseDuration(expiry)
    if err != nil {
        duration = 168 * time.Hour
    }
    claims := Claims{
        UserID: userID,
        Role:   role,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(duration)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
        },
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

func ValidateToken(tokenStr, secret string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
        if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, errors.New("unexpected signing method")
        }
        return []byte(secret), nil
    })
    if err != nil {
        return nil, err
    }
    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, errors.New("invalid token")
    }
    return claims, nil
}
```

#### `internal/middleware/auth.go`

```go
package middleware

import (
    "strings"
    "github.com/gin-gonic/gin"
    "github.com/bookify-rooms/backend/internal/utils"
)

func Auth(jwtSecret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        header := c.GetHeader("Authorization")
        if !strings.HasPrefix(header, "Bearer ") {
            utils.Error(c, 401, "unauthorized")
            c.Abort()
            return
        }
        claims, err := utils.ValidateToken(strings.TrimPrefix(header, "Bearer "), jwtSecret)
        if err != nil {
            utils.Error(c, 401, "invalid or expired token")
            c.Abort()
            return
        }
        c.Set("userID", claims.UserID)
        c.Set("role", claims.Role)
        c.Next()
    }
}

func RequireRole(roles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        role := c.GetString("role")
        for _, r := range roles {
            if r == role {
                c.Next()
                return
            }
        }
        utils.Error(c, 403, "forbidden: insufficient role")
        c.Abort()
    }
}
```

#### `internal/middleware/cors.go`

```go
package middleware

import (
    "github.com/gin-gonic/gin"
)

func CORS(allowedOrigins []string) gin.HandlerFunc {
    return func(c *gin.Context) {
        origin := c.GetHeader("Origin")
        allowed := false
        for _, o := range allowedOrigins {
            if o == "*" || o == origin {
                allowed = true
                break
            }
        }
        if allowed {
            c.Header("Access-Control-Allow-Origin", origin)
        }
        c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        c.Header("Access-Control-Allow-Headers", "Origin, Authorization, Content-Type")
        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }
        c.Next()
    }
}
```

#### `.env.example`

```
PORT=8080
DATABASE_URL=postgres://postgres:postgres@localhost:5432/bookify?sslmode=disable
JWT_SECRET=your-super-secret-key-change-in-production
JWT_EXPIRY=168h
UPLOADS_DIR=./uploads
ALLOWED_ORIGINS=*
```

#### `Makefile`

```makefile
.PHONY: run build migrate

run:
	go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

migrate:
	go run ./cmd/server migrate

test:
	go test ./... -v

docker-up:
	docker run -d --name bookify-postgres \
		-e POSTGRES_DB=bookify \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=postgres \
		-p 5432:5432 postgres:16-alpine

tidy:
	go mod tidy
```

### 4. Verifikasi

Setelah semua file dibuat, jalankan:
```bash
go mod tidy
go build ./...
```

Pastikan tidak ada error kompilasi.

## Catatan

- Gunakan `pgxpool` (connection pool) bukan `pgx` tunggal untuk production readiness
- Migration dijalankan otomatis saat server start dengan `RunMigrations()`
- Password di-hash dengan bcrypt, bukan plaintext
- JWT menggunakan HS256, secret dari env var
- `uploads/` folder untuk development; di production ganti dengan MinIO atau S3
