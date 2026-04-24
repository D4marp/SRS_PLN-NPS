# Go Admin

Implementasikan Admin dan Superadmin management panel di Go backend.

## Role Hierarchy

```
superadmin  →  Kelola semua user, bisa promote/demote admin
admin       →  Approve/reject booking, kelola rooms
booking     →  Petugas booking desk, akses kiosk mode
user        →  Regular user
```

## Endpoints Admin Panel

### Booking Management (admin + superadmin)

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/api/admin/bookings` | Semua booking (dengan filter status, date range, room) |
| GET | `/api/admin/bookings/pending` | Alias: pending bookings untuk approval queue |
| GET | `/api/admin/stats` | Dashboard stats (total bookings, pending, rooms, users) |

### User Management (superadmin only)

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/api/admin/users` | List semua user (dengan filter role, search) |
| GET | `/api/admin/users/:id` | Detail user |
| PATCH | `/api/admin/users/:id/role` | Ubah role user (promote/demote) |
| DELETE | `/api/admin/users/:id` | Hapus user |

## Tugas

### 1. Buat `internal/handlers/admin_handler.go`

```go
package handlers

import (
    "context"
    "net/http"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/models"
    "github.com/bookify-rooms/backend/internal/utils"
)

type AdminHandler struct {
    db *pgxpool.Pool
}

func NewAdminHandler(db *pgxpool.Pool) *AdminHandler {
    return &AdminHandler{db: db}
}

// =============================================================================
// DASHBOARD STATS
// =============================================================================

// GetStats godoc
// GET /api/admin/stats  [admin/superadmin]
func (h *AdminHandler) GetStats(c *gin.Context) {
    ctx := context.Background()

    var totalRooms, availableRooms int
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM rooms").Scan(&totalRooms)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM rooms WHERE is_available = true").Scan(&availableRooms)

    var totalUsers int
    var adminCount, bookingCount int
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE role = 'user'").Scan(&totalUsers)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE role = 'admin'").Scan(&adminCount)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE role = 'booking'").Scan(&bookingCount)

    var totalBookings, pendingBookings, confirmedBookings,
        rejectedBookings, cancelledBookings, completedBookings int

    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings").Scan(&totalBookings)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings WHERE status = 'pending'").Scan(&pendingBookings)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings WHERE status = 'confirmed'").Scan(&confirmedBookings)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings WHERE status = 'rejected'").Scan(&rejectedBookings)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings WHERE status = 'cancelled'").Scan(&cancelledBookings)
    h.db.QueryRow(ctx, "SELECT COUNT(*) FROM bookings WHERE status = 'completed'").Scan(&completedBookings)

    utils.Success(c, http.StatusOK, gin.H{
        "rooms": gin.H{
            "total":     totalRooms,
            "available": availableRooms,
        },
        "users": gin.H{
            "total":   totalUsers,
            "admins":  adminCount,
            "booking": bookingCount,
        },
        "bookings": gin.H{
            "total":     totalBookings,
            "pending":   pendingBookings,   // badge merah ini yang muncul di notification
            "confirmed": confirmedBookings,
            "rejected":  rejectedBookings,
            "cancelled": cancelledBookings,
            "completed": completedBookings,
        },
    })
}

// =============================================================================
// BOOKING MANAGEMENT (admin + superadmin)
// =============================================================================

// GetAdminBookings godoc
// GET /api/admin/bookings?status=pending&roomId=...&fromDate=...&toDate=...
// Endpoint khusus admin dengan filter lebih lengkap dibanding /api/bookings
func (h *AdminHandler) GetAdminBookings(c *gin.Context) {
    status := c.Query("status")
    roomID := c.Query("roomId")
    fromDate := c.Query("fromDate")  // epoch ms
    toDate := c.Query("toDate")      // epoch ms

    query := `SELECT ` + bookingSelectColsAdmin + `
              FROM bookings b
              JOIN users u ON b.user_id = u.id
              JOIN rooms r ON b.room_id = r.id
              WHERE 1=1`
    args := []interface{}{}
    idx := 1

    if status != "" {
        query += ` AND b.status = $` + itoa(idx)
        args = append(args, status)
        idx++
    }
    if roomID != "" {
        query += ` AND b.room_id = $` + itoa(idx)
        args = append(args, roomID)
        idx++
    }
    if fromDate != "" {
        query += ` AND b.booking_date >= $` + itoa(idx)
        args = append(args, fromDate)
        idx++
    }
    if toDate != "" {
        query += ` AND b.booking_date <= $` + itoa(idx)
        args = append(args, toDate)
        idx++
    }

    query += ` ORDER BY b.created_at DESC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch bookings")
        return
    }
    defer rows.Close()

    type AdminBookingView struct {
        models.Booking
        ReviewerName *string `json:"reviewerName"`
    }

    bookings := []AdminBookingView{}
    for rows.Next() {
        var b models.Booking
        var reviewerName *string
        if err := rows.Scan(
            &b.ID, &b.UserID, &b.RoomID, &b.BookingDate,
            &b.CheckInTime, &b.CheckOutTime, &b.NumberOfGuests,
            &b.Status, &b.Purpose,
            &b.RejectionReason, &b.ApprovedBy, &b.ApprovedAt,
            &b.RoomName, &b.RoomLocation, &b.RoomImageURL,
            &b.UserName, &b.UserEmail,
            &b.CreatedAt, &b.UpdatedAt,
            &reviewerName,
        ); err == nil {
            bookings = append(bookings, AdminBookingView{
                Booking:      b,
                ReviewerName: reviewerName,
            })
        }
    }
    utils.Success(c, http.StatusOK, bookings)
}

// bookingSelectColsAdmin includes join with approver name
const bookingSelectColsAdmin = `
    b.id, b.user_id, b.room_id, b.booking_date, b.check_in_time, b.check_out_time,
    b.number_of_guests, b.status, b.purpose,
    b.rejection_reason, b.approved_by, b.approved_at,
    b.room_name, b.room_location, b.room_image_url, b.user_name, b.user_email,
    b.created_at, b.updated_at,
    reviewer.name as reviewer_name
`

// =============================================================================
// USER MANAGEMENT (superadmin only)
// =============================================================================

// ListUsers godoc
// GET /api/admin/users?role=admin&search=john  [superadmin]
func (h *AdminHandler) ListUsers(c *gin.Context) {
    roleFilter := c.Query("role")
    search := strings.ToLower(c.Query("search"))

    query := `SELECT id, name, email, profile_image, city, role, created_at, updated_at
              FROM users WHERE 1=1`
    args := []interface{}{}
    idx := 1

    if roleFilter != "" {
        query += ` AND role = $` + itoa(idx)
        args = append(args, roleFilter)
        idx++
    }
    if search != "" {
        query += ` AND (LOWER(name) LIKE $` + itoa(idx) +
            ` OR LOWER(email) LIKE $` + itoa(idx) + `)`
        args = append(args, "%"+search+"%")
        idx++
    }

    query += ` ORDER BY created_at DESC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch users")
        return
    }
    defer rows.Close()

    users := []models.UserResponse{}
    for rows.Next() {
        var u models.User
        if err := rows.Scan(&u.ID, &u.Name, &u.Email, &u.ProfileImage,
            &u.City, &u.Role, &u.CreatedAt, &u.UpdatedAt); err == nil {
            users = append(users, u.ToResponse())
        }
    }
    utils.Success(c, http.StatusOK, users)
}

// GetUser godoc
// GET /api/admin/users/:id  [superadmin]
func (h *AdminHandler) GetUser(c *gin.Context) {
    id := c.Param("id")

    var u models.User
    err := h.db.QueryRow(context.Background(),
        `SELECT id, name, email, profile_image, city, role, created_at, updated_at
         FROM users WHERE id = $1`, id).
        Scan(&u.ID, &u.Name, &u.Email, &u.ProfileImage,
            &u.City, &u.Role, &u.CreatedAt, &u.UpdatedAt)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "user not found")
        return
    }
    utils.Success(c, http.StatusOK, u.ToResponse())
}

// ChangeUserRole godoc
// PATCH /api/admin/users/:id/role  [superadmin]
// Superadmin bisa promote user → admin atau booking, atau demote admin → user
func (h *AdminHandler) ChangeUserRole(c *gin.Context) {
    targetID := c.Param("id")
    currentUserID := c.GetString("userID")

    // Superadmin tidak bisa mengubah role dirinya sendiri
    if targetID == currentUserID {
        utils.Error(c, http.StatusBadRequest, "cannot change your own role")
        return
    }

    var req models.ChangeRoleRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    // Validasi role yang diminta valid
    if !models.ValidRoles[req.Role] {
        utils.Error(c, http.StatusBadRequest, "invalid role")
        return
    }

    // Tidak boleh promote user menjadi superadmin melalui API ini
    // (superadmin hanya dibuat manual di DB atau seed)
    if req.Role == models.RoleSuperAdmin {
        utils.Error(c, http.StatusForbidden, "superadmin role cannot be assigned via API")
        return
    }

    now := time.Now().UnixMilli()
    result, err := h.db.Exec(context.Background(),
        "UPDATE users SET role = $1, updated_at = $2 WHERE id = $3",
        string(req.Role), now, targetID)
    if err != nil || result.RowsAffected() == 0 {
        utils.Error(c, http.StatusNotFound, "user not found")
        return
    }

    utils.SuccessMessage(c, http.StatusOK, "user role updated",
        gin.H{"userId": targetID, "newRole": req.Role})
}

// DeleteUser godoc
// DELETE /api/admin/users/:id  [superadmin]
func (h *AdminHandler) DeleteUser(c *gin.Context) {
    targetID := c.Param("id")
    currentUserID := c.GetString("userID")

    if targetID == currentUserID {
        utils.Error(c, http.StatusBadRequest, "cannot delete your own account via this endpoint")
        return
    }

    // Cek target bukan superadmin lain
    var targetRole models.UserRole
    h.db.QueryRow(context.Background(),
        "SELECT role FROM users WHERE id = $1", targetID).Scan(&targetRole)
    if targetRole == models.RoleSuperAdmin {
        utils.Error(c, http.StatusForbidden, "cannot delete another superadmin")
        return
    }

    result, err := h.db.Exec(context.Background(),
        "DELETE FROM users WHERE id = $1", targetID)
    if err != nil || result.RowsAffected() == 0 {
        utils.Error(c, http.StatusNotFound, "user not found")
        return
    }

    utils.SuccessMessage(c, http.StatusOK, "user deleted", nil)
}
```

### 2. Registrasi Routes

Di `internal/server/router.go`:

```go
adminH := handlers.NewAdminHandler(db)
adminMw := middleware.RequireRole("admin", "superadmin")
superAdminMw := middleware.RequireRole("superadmin")

admin := r.Group("/api/admin")
admin.Use(authMiddleware)
{
    // Stats dashboard - admin + superadmin
    admin.GET("/stats", adminMw, adminH.GetStats)

    // Booking management - admin + superadmin
    admin.GET("/bookings", adminMw, adminH.GetAdminBookings)

    // User management - superadmin only
    admin.GET("/users", superAdminMw, adminH.ListUsers)
    admin.GET("/users/:id", superAdminMw, adminH.GetUser)
    admin.PATCH("/users/:id/role", superAdminMw, adminH.ChangeUserRole)
    admin.DELETE("/users/:id", superAdminMw, adminH.DeleteUser)
}
```

### 3. Update `middleware/auth.go`

Pastikan `RequireRole` mendukung multiple roles dan superadmin otomatis diizinkan di semua admin route:

```go
// RequireRole mengizinkan akses jika role user ada di list roles yang diizinkan
// Superadmin selalu diizinkan di semua route (sudah dicakup di router)
func RequireRole(roles ...string) gin.HandlerFunc {
    return func(c *gin.Context) {
        role := c.GetString("role")
        for _, r := range roles {
            if r == role {
                c.Next()
                return
            }
        }
        utils.Error(c, 403, "forbidden: requires role "+strings.Join(roles, " or "))
        c.Abort()
    }
}
```

## Flutter App — Admin Panel yang Perlu Dibuat

### Screen Baru di Flutter

```
Admin Panel (AdminRoomsScreen saat ini)
├── Tab 1: Rooms          ← sudah ada (add/edit/delete)
├── Tab 2: Bookings       ← BARU: approval queue
│   ├── Filter tabs: All | Pending | Confirmed | Rejected
│   ├── BookingCard dengan tombol:
│   │   ├── [pending]   → tombol Approve + Reject
│   │   ├── [confirmed] → tombol Mark Complete + Cancel
│   │   └── [rejected]  → read-only, tampilkan rejection_reason
│   └── Pending count badge di tab
└── Tab 3: Users          ← BARU: superadmin only
    ├── List semua user
    └── Per user: dropdown ubah role
```

### Perubahan di `home_screen.dart` / `profile_screen.dart`

```dart
// Tampilkan pending booking count sebagai notif badge
// Panggil GET /api/admin/stats untuk mendapatkan bookings.pending count
// Tampilkan badge merah di tombol Admin Panel
```

### Model Booking Flutter — Field Baru

Tambahkan field berikut ke `BookingModel`:
```dart
final String? rejectionReason;  // null jika bukan rejected
final String? approvedBy;        // user_id admin yang review
final int? approvedAt;           // timestamp review (millisecondsSinceEpoch)
```

## Superadmin Setup

Karena superadmin tidak bisa dibuat via API (security), setup manual pertama kali:

```sql
-- Jalankan sekali setelah server pertama kali di-deploy:
-- 1. Register akun via /api/auth/register seperti biasa
-- 2. Ubah role via SQL:
UPDATE users SET role = 'superadmin' WHERE email = 'superadmin@yourcompany.com';
```

Atau buat seed script di `internal/database/seed.go`:

```go
// SeedSuperAdmin creates the initial superadmin if not exists
func SeedSuperAdmin(db *pgxpool.Pool, email, password, name string) error {
    var count int
    db.QueryRow(context.Background(),
        "SELECT COUNT(*) FROM users WHERE role = 'superadmin'").Scan(&count)
    if count > 0 {
        return nil // sudah ada superadmin, skip
    }
    hashed, _ := utils.HashPassword(password)
    _, err := db.Exec(context.Background(),
        `INSERT INTO users (id, name, email, password, role, created_at)
         VALUES ($1, $2, $3, $4, 'superadmin', $5)`,
        uuid.New().String(), name, email, hashed, time.Now().UnixMilli())
    return err
}
```

Di `cmd/server/main.go`:
```go
// Seed superadmin dari env vars
if cfg.SuperAdminEmail != "" {
    database.SeedSuperAdmin(db, cfg.SuperAdminEmail, cfg.SuperAdminPassword, "Super Admin")
}
```

Di `.env`:
```
SUPERADMIN_EMAIL=superadmin@yourcompany.com
SUPERADMIN_PASSWORD=change-this-immediately
```

## Testing

```bash
# Get dashboard stats (admin)
curl http://localhost:8080/api/admin/stats \
  -H "Authorization: Bearer ADMIN_TOKEN"

# List semua user (superadmin)
curl http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer SUPERADMIN_TOKEN"

# Promote user ke admin (superadmin)
curl -X PATCH http://localhost:8080/api/admin/users/{user-id}/role \
  -H "Authorization: Bearer SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}'

# Filter booking pending (admin)
curl "http://localhost:8080/api/admin/bookings?status=pending" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```
