# Go Bookings

Implementasikan Bookings CRUD API dengan **approval workflow** di Go.

## Booking Status Flow

```
User submit → [pending] → Admin approve → [confirmed] → Admin complete → [completed]
                        ↘ Admin reject  → [rejected]
             [confirmed] → User/Admin cancel → [cancelled]
```

**Perbedaan dari versi sebelumnya (Firebase):**
- Firebase: booking langsung `confirmed` tanpa approval
- Go backend: booking mulai sebagai `pending`, harus diapprove admin

## Endpoints

| Method | Path | Auth | Role | Keterangan |
|--------|------|------|------|------------|
| GET | `/api/bookings` | Yes | any | List bookings (user: own, admin: all) |
| GET | `/api/bookings/:id` | Yes | any | Get booking by ID |
| POST | `/api/bookings` | Yes | user/booking | Buat booking baru → status: pending |
| POST | `/api/bookings/:id/approve` | Yes | admin/superadmin | Approve → confirmed |
| POST | `/api/bookings/:id/reject` | Yes | admin/superadmin | Reject → rejected (wajib reason) |
| PATCH | `/api/bookings/:id/cancel` | Yes | owner/admin | Cancel confirmed booking |
| PATCH | `/api/bookings/:id/complete` | Yes | admin/superadmin | Mark completed |
| GET | `/api/rooms/:id/bookings` | No | any | Schedule ruangan (confirmed only) |
| GET | `/api/bookings/pending` | Yes | admin/superadmin | Semua pending (shortcut admin) |

## Tugas

Buat `backend/internal/handlers/booking_handler.go`:

```go
package handlers

import (
    "context"
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/models"
    "github.com/bookify-rooms/backend/internal/utils"
)

type BookingHandler struct {
    db *pgxpool.Pool
}

func NewBookingHandler(db *pgxpool.Pool) *BookingHandler {
    return &BookingHandler{db: db}
}

const bookingSelectCols = `
    id, user_id, room_id, booking_date, check_in_time, check_out_time,
    number_of_guests, status, purpose,
    rejection_reason, approved_by, approved_at,
    room_name, room_location, room_image_url, user_name, user_email,
    created_at, updated_at
`

func scanBooking(row interface{ Scan(...interface{}) error }, b *models.Booking) error {
    return row.Scan(
        &b.ID, &b.UserID, &b.RoomID, &b.BookingDate,
        &b.CheckInTime, &b.CheckOutTime, &b.NumberOfGuests,
        &b.Status, &b.Purpose,
        &b.RejectionReason, &b.ApprovedBy, &b.ApprovedAt,
        &b.RoomName, &b.RoomLocation, &b.RoomImageURL,
        &b.UserName, &b.UserEmail,
        &b.CreatedAt, &b.UpdatedAt,
    )
}

// -----------------------------------------------------------------------------
// ListBookings — GET /api/bookings
// User biasa: hanya booking miliknya
// Admin/superadmin: semua, bisa filter by userId/roomId/status
// -----------------------------------------------------------------------------
func (h *BookingHandler) ListBookings(c *gin.Context) {
    currentUserID := c.GetString("userID")
    role := c.GetString("role")

    var filter models.BookingFilter
    c.ShouldBindQuery(&filter)

    query := `SELECT ` + bookingSelectCols + ` FROM bookings WHERE 1=1`
    args := []interface{}{}
    idx := 1

    if role != "admin" && role != "superadmin" {
        query += ` AND user_id = $` + itoa(idx)
        args = append(args, currentUserID)
        idx++
    } else if filter.UserID != "" {
        query += ` AND user_id = $` + itoa(idx)
        args = append(args, filter.UserID)
        idx++
    }

    if filter.RoomID != "" {
        query += ` AND room_id = $` + itoa(idx)
        args = append(args, filter.RoomID)
        idx++
    }
    if filter.Status != "" {
        query += ` AND status = $` + itoa(idx)
        args = append(args, string(filter.Status))
        idx++
    }

    query += ` ORDER BY created_at DESC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch bookings")
        return
    }
    defer rows.Close()

    bookings := []models.Booking{}
    for rows.Next() {
        var b models.Booking
        if err := scanBooking(rows, &b); err == nil {
            bookings = append(bookings, b)
        }
    }
    utils.Success(c, http.StatusOK, bookings)
}

// -----------------------------------------------------------------------------
// GetPendingBookings — GET /api/bookings/pending (admin shortcut)
// Mengembalikan semua booking dengan status pending, diurutkan paling lama dulu
// -----------------------------------------------------------------------------
func (h *BookingHandler) GetPendingBookings(c *gin.Context) {
    rows, err := h.db.Query(context.Background(),
        `SELECT `+bookingSelectCols+`
         FROM bookings WHERE status = 'pending'
         ORDER BY created_at ASC`) // oldest first, FIFO
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch pending bookings")
        return
    }
    defer rows.Close()

    bookings := []models.Booking{}
    for rows.Next() {
        var b models.Booking
        if err := scanBooking(rows, &b); err == nil {
            bookings = append(bookings, b)
        }
    }
    utils.Success(c, http.StatusOK, bookings)
}

// -----------------------------------------------------------------------------
// GetBooking — GET /api/bookings/:id
// -----------------------------------------------------------------------------
func (h *BookingHandler) GetBooking(c *gin.Context) {
    id := c.Param("id")
    currentUserID := c.GetString("userID")
    role := c.GetString("role")

    var b models.Booking
    err := scanBooking(
        h.db.QueryRow(context.Background(),
            `SELECT `+bookingSelectCols+` FROM bookings WHERE id = $1`, id),
        &b,
    )
    if err != nil {
        utils.Error(c, http.StatusNotFound, "booking not found")
        return
    }

    if role != "admin" && role != "superadmin" && b.UserID != currentUserID {
        utils.Error(c, http.StatusForbidden, "access denied")
        return
    }
    utils.Success(c, http.StatusOK, b)
}

// -----------------------------------------------------------------------------
// CreateBooking — POST /api/bookings
// Status AWAL: pending (menunggu approval admin)
// -----------------------------------------------------------------------------
func (h *BookingHandler) CreateBooking(c *gin.Context) {
    userID := c.GetString("userID")

    var req models.CreateBookingRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    // Validasi room
    var room models.Room
    err := h.db.QueryRow(context.Background(),
        `SELECT id, name, location, image_urls, max_guests, is_available
         FROM rooms WHERE id = $1`, req.RoomID).
        Scan(&room.ID, &room.Name, &room.Location, &room.ImageURLs,
            &room.MaxGuests, &room.IsAvailable)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "room not found")
        return
    }
    if !room.IsAvailable {
        utils.Error(c, http.StatusBadRequest, "room is not available")
        return
    }
    if req.NumberOfGuests > room.MaxGuests {
        utils.Error(c, http.StatusBadRequest, "number of guests exceeds room capacity")
        return
    }

    // Server-side conflict check: cek overlap dengan booking yang pending/confirmed
    // (bukan rejected/cancelled/completed)
    var conflictCount int
    h.db.QueryRow(context.Background(),
        `SELECT COUNT(*) FROM bookings
         WHERE room_id = $1
           AND booking_date = $2
           AND status IN ('pending', 'confirmed')
           AND check_in_time < $3
           AND check_out_time > $4`,
        req.RoomID, req.BookingDate, req.CheckOutTime, req.CheckInTime,
    ).Scan(&conflictCount)
    if conflictCount > 0 {
        utils.Error(c, http.StatusConflict, "time slot is unavailable or pending approval")
        return
    }

    // Denormalize user data
    var uName, uEmail string
    h.db.QueryRow(context.Background(),
        `SELECT name, email FROM users WHERE id = $1`, userID).
        Scan(&uName, &uEmail)

    now := time.Now().UnixMilli()
    roomImageURL := ""
    if len(room.ImageURLs) > 0 {
        roomImageURL = room.ImageURLs[0]
    }

    booking := models.Booking{
        ID:             uuid.New().String(),
        UserID:         userID,
        RoomID:         req.RoomID,
        BookingDate:    req.BookingDate,
        CheckInTime:    req.CheckInTime,
        CheckOutTime:   req.CheckOutTime,
        NumberOfGuests: req.NumberOfGuests,
        Status:         models.StatusPending, // ← pending, bukan langsung confirmed
        Purpose:        req.Purpose,
        RoomName:       &room.Name,
        RoomLocation:   &room.Location,
        RoomImageURL:   &roomImageURL,
        UserName:       &uName,
        UserEmail:      &uEmail,
        CreatedAt:      now,
    }

    _, err = h.db.Exec(context.Background(),
        `INSERT INTO bookings (id, user_id, room_id, booking_date, check_in_time, check_out_time,
                              number_of_guests, status, purpose,
                              room_name, room_location, room_image_url,
                              user_name, user_email, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
        booking.ID, booking.UserID, booking.RoomID, booking.BookingDate,
        booking.CheckInTime, booking.CheckOutTime, booking.NumberOfGuests,
        booking.Status, booking.Purpose,
        booking.RoomName, booking.RoomLocation, booking.RoomImageURL,
        booking.UserName, booking.UserEmail, booking.CreatedAt,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to create booking")
        return
    }

    // Audit trail
    h.recordHistory(booking.ID, "", "pending", userID, "booking created")

    utils.SuccessMessage(c, http.StatusCreated,
        "booking submitted, waiting for admin approval", booking)
}

// -----------------------------------------------------------------------------
// ApproveBooking — POST /api/bookings/:id/approve  [admin/superadmin]
// pending → confirmed
// -----------------------------------------------------------------------------
func (h *BookingHandler) ApproveBooking(c *gin.Context) {
    id := c.Param("id")
    adminID := c.GetString("userID")

    var req models.ApproveBookingRequest
    c.ShouldBindJSON(&req) // opsional

    // Hanya booking berstatus pending yang bisa diapprove
    var currentStatus models.BookingStatus
    err := h.db.QueryRow(context.Background(),
        "SELECT status FROM bookings WHERE id = $1", id).Scan(&currentStatus)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "booking not found")
        return
    }
    if currentStatus != models.StatusPending {
        utils.Error(c, http.StatusBadRequest,
            "only pending bookings can be approved (current: "+string(currentStatus)+")")
        return
    }

    now := time.Now().UnixMilli()
    _, err = h.db.Exec(context.Background(),
        `UPDATE bookings
         SET status = 'confirmed', approved_by = $1, approved_at = $2, updated_at = $2
         WHERE id = $3`,
        adminID, now, id)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to approve booking")
        return
    }

    note := "approved by admin"
    if req.Note != nil {
        note = *req.Note
    }
    h.recordHistory(id, "pending", "confirmed", adminID, note)

    utils.SuccessMessage(c, http.StatusOK, "booking approved",
        gin.H{"id": id, "status": "confirmed"})
}

// -----------------------------------------------------------------------------
// RejectBooking — POST /api/bookings/:id/reject  [admin/superadmin]
// pending → rejected  (reason wajib diisi)
// -----------------------------------------------------------------------------
func (h *BookingHandler) RejectBooking(c *gin.Context) {
    id := c.Param("id")
    adminID := c.GetString("userID")

    var req models.RejectBookingRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, "rejection reason is required: "+err.Error())
        return
    }

    var currentStatus models.BookingStatus
    err := h.db.QueryRow(context.Background(),
        "SELECT status FROM bookings WHERE id = $1", id).Scan(&currentStatus)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "booking not found")
        return
    }
    if currentStatus != models.StatusPending {
        utils.Error(c, http.StatusBadRequest,
            "only pending bookings can be rejected (current: "+string(currentStatus)+")")
        return
    }

    now := time.Now().UnixMilli()
    _, err = h.db.Exec(context.Background(),
        `UPDATE bookings
         SET status = 'rejected', rejection_reason = $1,
             approved_by = $2, approved_at = $3, updated_at = $3
         WHERE id = $4`,
        req.Reason, adminID, now, id)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to reject booking")
        return
    }

    h.recordHistory(id, "pending", "rejected", adminID, req.Reason)

    utils.SuccessMessage(c, http.StatusOK, "booking rejected",
        gin.H{"id": id, "status": "rejected", "reason": req.Reason})
}

// -----------------------------------------------------------------------------
// CancelBooking — PATCH /api/bookings/:id/cancel
// confirmed → cancelled  (oleh owner atau admin)
// -----------------------------------------------------------------------------
func (h *BookingHandler) CancelBooking(c *gin.Context) {
    id := c.Param("id")
    userID := c.GetString("userID")
    role := c.GetString("role")

    var ownerID string
    var status models.BookingStatus
    err := h.db.QueryRow(context.Background(),
        "SELECT user_id, status FROM bookings WHERE id = $1", id).
        Scan(&ownerID, &status)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "booking not found")
        return
    }

    isAdmin := role == "admin" || role == "superadmin"
    if !isAdmin && ownerID != userID {
        utils.Error(c, http.StatusForbidden, "access denied")
        return
    }
    if status != models.StatusConfirmed && status != models.StatusPending {
        utils.Error(c, http.StatusBadRequest,
            "only pending or confirmed bookings can be cancelled")
        return
    }

    now := time.Now().UnixMilli()
    h.db.Exec(context.Background(),
        "UPDATE bookings SET status = 'cancelled', updated_at = $1 WHERE id = $2",
        now, id)

    h.recordHistory(id, string(status), "cancelled", userID, "cancelled by user/admin")
    utils.SuccessMessage(c, http.StatusOK, "booking cancelled",
        gin.H{"id": id, "status": "cancelled"})
}

// -----------------------------------------------------------------------------
// CompleteBooking — PATCH /api/bookings/:id/complete  [admin/superadmin]
// confirmed → completed
// -----------------------------------------------------------------------------
func (h *BookingHandler) CompleteBooking(c *gin.Context) {
    id := c.Param("id")
    adminID := c.GetString("userID")

    var status models.BookingStatus
    err := h.db.QueryRow(context.Background(),
        "SELECT status FROM bookings WHERE id = $1", id).Scan(&status)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "booking not found")
        return
    }
    if status != models.StatusConfirmed {
        utils.Error(c, http.StatusBadRequest, "only confirmed bookings can be completed")
        return
    }

    now := time.Now().UnixMilli()
    h.db.Exec(context.Background(),
        "UPDATE bookings SET status = 'completed', updated_at = $1 WHERE id = $2",
        now, id)

    h.recordHistory(id, "confirmed", "completed", adminID, "marked completed by admin")
    utils.SuccessMessage(c, http.StatusOK, "booking completed",
        gin.H{"id": id, "status": "completed"})
}

// -----------------------------------------------------------------------------
// GetRoomBookings — GET /api/rooms/:id/bookings?date=...
// Digunakan Flutter app untuk menampilkan schedule di room detail screen
// Hanya mengembalikan booking confirmed (bukan pending/rejected/dll)
// -----------------------------------------------------------------------------
func (h *BookingHandler) GetRoomBookings(c *gin.Context) {
    roomID := c.Param("id")
    dateStr := c.Query("date")

    query := `SELECT ` + bookingSelectCols + `
              FROM bookings
              WHERE room_id = $1 AND status IN ('pending', 'confirmed')`
    args := []interface{}{roomID}

    if dateStr != "" {
        query += ` AND booking_date = $2`
        args = append(args, dateStr)
    }
    query += ` ORDER BY check_in_time ASC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch room bookings")
        return
    }
    defer rows.Close()

    bookings := []models.Booking{}
    for rows.Next() {
        var b models.Booking
        if err := scanBooking(rows, &b); err == nil {
            bookings = append(bookings, b)
        }
    }
    utils.Success(c, http.StatusOK, bookings)
}

// recordHistory mencatat perubahan status ke booking_status_history
func (h *BookingHandler) recordHistory(bookingID, from, to, changedBy, note string) {
    h.db.Exec(context.Background(),
        `INSERT INTO booking_status_history
         (id, booking_id, from_status, to_status, changed_by, note, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        uuid.New().String(), bookingID, from, to, changedBy, note, time.Now().UnixMilli(),
    )
}
```

## Registrasi Routes

Di `internal/server/router.go`:

```go
bookingH := handlers.NewBookingHandler(db)
adminMw := middleware.RequireRole("admin", "superadmin")

// User booking routes
bookings := r.Group("/api/bookings")
bookings.Use(authMiddleware)
{
    bookings.GET("", bookingH.ListBookings)
    bookings.GET("/pending", adminMw, bookingH.GetPendingBookings) // admin shortcut
    bookings.GET("/:id", bookingH.GetBooking)
    bookings.POST("", bookingH.CreateBooking)                      // → status:pending
    bookings.POST("/:id/approve", adminMw, bookingH.ApproveBooking)
    bookings.POST("/:id/reject", adminMw, bookingH.RejectBooking)
    bookings.PATCH("/:id/cancel", bookingH.CancelBooking)
    bookings.PATCH("/:id/complete", adminMw, bookingH.CompleteBooking)
}

// Room schedule (public, untuk kiosk mode)
r.GET("/api/rooms/:id/bookings", bookingH.GetRoomBookings)
```

## Flutter App Changes yang Diperlukan

| Flutter kode lama | Pengganti |
|------------------|-----------|
| `BookingStatus.confirmed` saat create | `BookingStatus.pending` |
| Tidak ada approval button | Tambah screen admin booking |
| `canBeCancelled` = pending/confirmed | Tetap sama |

### Notifikasi ke User

Karena booking sekarang butuh approval, Flutter perlu:
1. Tampilkan badge/counter "pending" di booking history screen
2. Saat status berubah ke `confirmed`/`rejected`, tampilkan notifikasi
3. Tampilkan `rejectionReason` di booking detail jika status `rejected`

## Testing

```bash
# Buat booking (status: pending)
curl -X POST http://localhost:8080/api/bookings \
  -H "Authorization: Bearer USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"roomId":"xxx","bookingDate":1741564800000,"checkInTime":"09:00","checkOutTime":"11:00","numberOfGuests":5}'

# Admin: lihat semua pending
curl http://localhost:8080/api/bookings/pending \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Admin: approve
curl -X POST http://localhost:8080/api/bookings/{id}/approve \
  -H "Authorization: Bearer ADMIN_TOKEN"

# Admin: reject (reason wajib)
curl -X POST http://localhost:8080/api/bookings/{id}/reject \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reason":"Ruangan sudah diprioritaskan untuk acara kantor"}'
```
