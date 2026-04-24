# Go Auth

Implementasikan sistem autentikasi JWT untuk menggantikan Firebase Auth pada Bookify Rooms.

## Role yang Didukung

| Role | Keterangan |
|------|------------|
| `user` | Default saat register, bisa buat booking |
| `booking` | Petugas booking desk / kiosk mode |
| `admin` | Approve/reject booking, kelola rooms |
| `superadmin` | Kelola semua user + semua fitur admin |

> `IsAdmin()` berlaku untuk **keduanya** `admin` dan `superadmin`.
> Superadmin tidak bisa di-assign via API — hanya via SQL seed (security).

## Endpoints yang Akan Dibuat

| Method | Path | Auth? | Keterangan |
|--------|------|-------|------------|
| POST | `/api/auth/register` | No | Daftar akun baru |
| POST | `/api/auth/login` | No | Login, return JWT |
| POST | `/api/auth/logout` | Yes | Logout (client-side) |
| POST | `/api/auth/forgot-password` | No | Kirim email reset password |
| GET | `/api/auth/me` | Yes | Get current user info |
| PATCH | `/api/auth/me/city` | Yes | Update city dari GPS |
| PUT | `/api/auth/me` | Yes | Update profile |
| DELETE | `/api/auth/me` | Yes | Hapus akun |

## Pemetaan dari Firebase Auth

| Firebase | Go Backend |
|---------|------------|
| `FirebaseAuth.createUserWithEmailAndPassword()` | `POST /api/auth/register` |
| `FirebaseAuth.signInWithEmailAndPassword()` | `POST /api/auth/login` |
| `FirebaseAuth.signOut()` | `POST /api/auth/logout` (client hapus token) |
| `FirebaseAuth.sendPasswordResetEmail()` | `POST /api/auth/forgot-password` |
| `authStateChanges()` stream | Check JWT di setiap request via middleware |
| `users/{uid}` Firestore doc | `users` table di PostgreSQL |

## Tugas

Buat `backend/internal/handlers/auth_handler.go`:

```go
package handlers

import (
    "context"
    "time"
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/models"
    "github.com/bookify-rooms/backend/internal/utils"
)

type AuthHandler struct {
    db        *pgxpool.Pool
    jwtSecret string
    jwtExpiry string
}

func NewAuthHandler(db *pgxpool.Pool, jwtSecret, jwtExpiry string) *AuthHandler {
    return &AuthHandler{db: db, jwtSecret: jwtSecret, jwtExpiry: jwtExpiry}
}

// Register godoc
// POST /api/auth/register
func (h *AuthHandler) Register(c *gin.Context) {
    var req models.RegisterRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    // Check email sudah terdaftar
    var count int
    err := h.db.QueryRow(context.Background(),
        "SELECT COUNT(*) FROM users WHERE email = $1", req.Email).Scan(&count)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "database error")
        return
    }
    if count > 0 {
        utils.Error(c, http.StatusConflict, "email already registered")
        return
    }

    // Hash password
    hashed, err := utils.HashPassword(req.Password)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to hash password")
        return
    }

    now := time.Now().UnixMilli()
    user := models.User{
        ID:        uuid.New().String(),
        Name:      req.Name,
        Email:     req.Email,
        Password:  hashed,
        Role:      models.RoleUser,
        CreatedAt: now,
    }

    _, err = h.db.Exec(context.Background(),
        `INSERT INTO users (id, name, email, password, role, created_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        user.ID, user.Name, user.Email, user.Password, user.Role, user.CreatedAt,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to create user")
        return
    }

    token, err := utils.GenerateToken(user.ID, string(user.Role), h.jwtSecret, h.jwtExpiry)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to generate token")
        return
    }

    utils.SuccessMessage(c, http.StatusCreated, "registration successful", models.AuthResponse{
        Token: token,
        User:  user.ToResponse(),
    })
}

// Login godoc
// POST /api/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
    var req models.LoginRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    var user models.User
    err := h.db.QueryRow(context.Background(),
        `SELECT id, name, email, password, profile_image, city, role, created_at, updated_at
         FROM users WHERE email = $1`, req.Email).
        Scan(&user.ID, &user.Name, &user.Email, &user.Password,
            &user.ProfileImage, &user.City, &user.Role,
            &user.CreatedAt, &user.UpdatedAt)
    if err != nil {
        utils.Error(c, http.StatusUnauthorized, "invalid email or password")
        return
    }

    if !utils.CheckPassword(req.Password, user.Password) {
        utils.Error(c, http.StatusUnauthorized, "invalid email or password")
        return
    }

    token, err := utils.GenerateToken(user.ID, string(user.Role), h.jwtSecret, h.jwtExpiry)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to generate token")
        return
    }

    utils.Success(c, http.StatusOK, models.AuthResponse{
        Token: token,
        User:  user.ToResponse(),
    })
}

// Me godoc
// GET /api/auth/me  [requires: Auth middleware]
func (h *AuthHandler) Me(c *gin.Context) {
    userID := c.GetString("userID")

    var user models.User
    err := h.db.QueryRow(context.Background(),
        `SELECT id, name, email, profile_image, city, role, created_at, updated_at
         FROM users WHERE id = $1`, userID).
        Scan(&user.ID, &user.Name, &user.Email,
            &user.ProfileImage, &user.City, &user.Role,
            &user.CreatedAt, &user.UpdatedAt)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "user not found")
        return
    }

    utils.Success(c, http.StatusOK, user.ToResponse())
}

// UpdateMe godoc
// PUT /api/auth/me  [requires: Auth middleware]
func (h *AuthHandler) UpdateMe(c *gin.Context) {
    userID := c.GetString("userID")

    var req models.UpdateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    now := time.Now().UnixMilli()
    _, err := h.db.Exec(context.Background(),
        `UPDATE users SET
            name = COALESCE($1, name),
            profile_image = COALESCE($2, profile_image),
            city = COALESCE($3, city),
            updated_at = $4
         WHERE id = $5`,
        req.Name, req.ProfileImage, req.City, now, userID,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to update user")
        return
    }

    // Return updated user
    var user models.User
    h.db.QueryRow(context.Background(),
        `SELECT id, name, email, profile_image, city, role, created_at, updated_at
         FROM users WHERE id = $1`, userID).
        Scan(&user.ID, &user.Name, &user.Email,
            &user.ProfileImage, &user.City, &user.Role,
            &user.CreatedAt, &user.UpdatedAt)

    utils.Success(c, http.StatusOK, user.ToResponse())
}

// UpdateCity godoc
// PATCH /api/auth/me/city  [requires: Auth middleware]
// Dipanggil Flutter app saat berhasil detect GPS location
func (h *AuthHandler) UpdateCity(c *gin.Context) {
    userID := c.GetString("userID")

    var req models.UpdateCityRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    now := time.Now().UnixMilli()
    _, err := h.db.Exec(context.Background(),
        `UPDATE users SET city = $1, updated_at = $2 WHERE id = $3`,
        req.City, now, userID,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to update city")
        return
    }

    utils.SuccessMessage(c, http.StatusOK, "city updated", gin.H{"city": req.City})
}

// ForgotPassword godoc
// POST /api/auth/forgot-password
// Note: Implementasi kirim email sesuai email provider yang digunakan
func (h *AuthHandler) ForgotPassword(c *gin.Context) {
    var req struct {
        Email string `json:"email" binding:"required,email"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    // Check apakah email terdaftar (jangan kasih info ke user untuk security)
    var count int
    h.db.QueryRow(context.Background(),
        "SELECT COUNT(*) FROM users WHERE email = $1", req.Email).Scan(&count)

    // Selalu return success agar tidak leak info user terdaftar atau tidak
    // TODO: Implementasi kirim reset password email via SMTP/SendGrid/etc.
    utils.SuccessMessage(c, http.StatusOK, "if the email is registered, a reset link has been sent", nil)
}

// DeleteAccount godoc
// DELETE /api/auth/me  [requires: Auth middleware]
func (h *AuthHandler) DeleteAccount(c *gin.Context) {
    userID := c.GetString("userID")

    _, err := h.db.Exec(context.Background(),
        "DELETE FROM users WHERE id = $1", userID)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to delete account")
        return
    }

    utils.SuccessMessage(c, http.StatusOK, "account deleted successfully", nil)
}

// Logout godoc
// POST /api/auth/logout  [requires: Auth middleware]
// JWT adalah stateless — logout cukup dilakukan di sisi client dengan menghapus token.
// Endpoint ini hanya untuk konsistensi API.
func (h *AuthHandler) Logout(c *gin.Context) {
    utils.SuccessMessage(c, http.StatusOK, "logged out successfully", nil)
}
```

## Registrasi Routes

Di `internal/server/router.go` (buat file ini), tambahkan:

```go
authH := handlers.NewAuthHandler(db, cfg.JWTSecret, cfg.JWTExpiry)
authMiddleware := middleware.Auth(cfg.JWTSecret)

auth := r.Group("/api/auth")
{
    auth.POST("/register", authH.Register)
    auth.POST("/login", authH.Login)
    auth.POST("/forgot-password", authH.ForgotPassword)

    // Protected routes
    auth.GET("/me", authMiddleware, authH.Me)
    auth.PUT("/me", authMiddleware, authH.UpdateMe)
    auth.PATCH("/me/city", authMiddleware, authH.UpdateCity)
    auth.DELETE("/me", authMiddleware, authH.DeleteAccount)
    auth.POST("/logout", authMiddleware, authH.Logout)
}

// Role-based middleware contoh penggunaan:
// adminMw    := middleware.RequireRole("admin", "superadmin")
// superMw    := middleware.RequireRole("superadmin")
```

## Flutter App Changes yang Diperlukan

Di Flutter, ganti semua `AuthService` calls:

| Firebase | Go Backend API |
|---------|----------------|
| `FirebaseAuth.createUserWithEmailAndPassword()` | `POST /api/auth/register` → simpan JWT di `SharedPreferences` |
| `FirebaseAuth.signInWithEmailAndPassword()` | `POST /api/auth/login` → simpan JWT di `SharedPreferences` |
| `FirebaseAuth.signOut()` | `POST /api/auth/logout` + hapus JWT dari `SharedPreferences` |
| `FirebaseAuth.sendPasswordResetEmail()` | `POST /api/auth/forgot-password` |
| `FirebaseAuth.authStateChanges()` stream | Cek JWT di `SharedPreferences` saat app start |

### Role check di Flutter

```dart
// UserRole enum yang perlu diupdate di Flutter:
enum UserRole { user, booking, admin, superadmin }

extension UserRoleX on UserRole {
  // IsAdmin berlaku untuk admin DAN superadmin
  bool get isAdmin => this == UserRole.admin || this == UserRole.superadmin;
  bool get isSuperAdmin => this == UserRole.superadmin;
}
```

### Admin panel visibility di Flutter

```dart
// Profile screen: tampilkan Admin Panel untuk admin + superadmin
if (userModel.role.isAdmin) ...[
  _buildMenuCard(title: 'Admin Panel', ...),
]

// Dalam admin panel: tampilkan User Management hanya untuk superadmin
if (userModel.role.isSuperAdmin) ...[
  Tab(text: 'Users'),
]
```

## Testing dengan cURL

```bash
# Register
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"password123"}'

# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get current user (ganti TOKEN dengan JWT dari login)
curl http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer TOKEN"
```
