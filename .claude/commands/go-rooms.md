# Go Rooms

Implementasikan Rooms CRUD API di Go untuk menggantikan Firestore `rooms` collection.

## Endpoints yang Akan Dibuat

| Method | Path | Auth? | Role | Keterangan |
|--------|------|-------|------|------------|
| GET | `/api/rooms` | Optional | any | List rooms dengan filter/search |
| GET | `/api/rooms/:id` | No | any | Get room by ID |
| POST | `/api/rooms` | Yes | admin | Tambah room baru |
| PUT | `/api/rooms/:id` | Yes | admin | Update room |
| DELETE | `/api/rooms/:id` | Yes | admin | Hapus room |
| GET | `/api/rooms/:id/bookings` | No | any | Bookings di room ini (hari ini) |

## Pemetaan dari Firestore

| Firestore Query | SQL Equivalent |
|----------------|----------------|
| `rooms.orderBy('createdAt', descending: true).snapshots()` | `SELECT * FROM rooms ORDER BY created_at DESC` |
| `rooms.where('city', isEqualTo: city).where('isAvailable', isEqualTo: true)` | `SELECT * FROM rooms WHERE city = $1 AND is_available = true` |
| `rooms.where('isAvailable', isEqualTo: true).get()` | `SELECT * FROM rooms WHERE is_available = true` |
| `rooms.doc(roomId).get()` | `SELECT * FROM rooms WHERE id = $1` |
| `rooms.add(roomData)` | `INSERT INTO rooms ...` |
| `rooms.doc(roomId).update(roomData)` | `UPDATE rooms SET ... WHERE id = $1` |
| `rooms.doc(roomId).delete()` | `DELETE FROM rooms WHERE id = $1` |

## Tugas

Buat `backend/internal/handlers/room_handler.go`:

```go
package handlers

import (
    "context"
    "net/http"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/models"
    "github.com/bookify-rooms/backend/internal/utils"
)

type RoomHandler struct {
    db *pgxpool.Pool
}

func NewRoomHandler(db *pgxpool.Pool) *RoomHandler {
    return &RoomHandler{db: db}
}

// ListRooms godoc
// GET /api/rooms?city=...&roomClass=...&hasAC=true&minGuests=10&search=...&available=true
func (h *RoomHandler) ListRooms(c *gin.Context) {
    var filter models.RoomFilter
    if err := c.ShouldBindQuery(&filter); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    query := `SELECT id, name, description, location, city, room_class, image_urls, amenities,
                     has_ac, is_available, max_guests, contact_number, floor, building,
                     created_at, updated_at
              FROM rooms WHERE 1=1`
    args := []interface{}{}
    idx := 1

    if filter.City != "" {
        query += ` AND city = $` + itoa(idx)
        args = append(args, filter.City)
        idx++
    }
    if filter.RoomClass != "" {
        query += ` AND room_class = $` + itoa(idx)
        args = append(args, string(filter.RoomClass))
        idx++
    }
    if filter.HasAC != nil {
        query += ` AND has_ac = $` + itoa(idx)
        args = append(args, *filter.HasAC)
        idx++
    }
    if filter.MinGuests != nil {
        query += ` AND max_guests >= $` + itoa(idx)
        args = append(args, *filter.MinGuests)
        idx++
    }
    if filter.Available != nil {
        query += ` AND is_available = $` + itoa(idx)
        args = append(args, *filter.Available)
        idx++
    }
    if filter.Search != "" {
        query += ` AND (LOWER(name) LIKE $` + itoa(idx) +
            ` OR LOWER(location) LIKE $` + itoa(idx) +
            ` OR LOWER(city) LIKE $` + itoa(idx) + `)`
        args = append(args, "%"+strings.ToLower(filter.Search)+"%")
        idx++
    }

    query += ` ORDER BY created_at DESC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to fetch rooms")
        return
    }
    defer rows.Close()

    rooms := []models.Room{}
    for rows.Next() {
        var r models.Room
        if err := rows.Scan(
            &r.ID, &r.Name, &r.Description, &r.Location, &r.City, &r.RoomClass,
            &r.ImageURLs, &r.Amenities, &r.HasAC, &r.IsAvailable,
            &r.MaxGuests, &r.ContactNumber, &r.Floor, &r.Building,
            &r.CreatedAt, &r.UpdatedAt,
        ); err != nil {
            continue
        }
        rooms = append(rooms, r)
    }

    utils.Success(c, http.StatusOK, rooms)
}

// GetRoom godoc
// GET /api/rooms/:id
func (h *RoomHandler) GetRoom(c *gin.Context) {
    id := c.Param("id")

    var r models.Room
    err := h.db.QueryRow(context.Background(),
        `SELECT id, name, description, location, city, room_class, image_urls, amenities,
                has_ac, is_available, max_guests, contact_number, floor, building,
                created_at, updated_at
         FROM rooms WHERE id = $1`, id).
        Scan(&r.ID, &r.Name, &r.Description, &r.Location, &r.City, &r.RoomClass,
            &r.ImageURLs, &r.Amenities, &r.HasAC, &r.IsAvailable,
            &r.MaxGuests, &r.ContactNumber, &r.Floor, &r.Building,
            &r.CreatedAt, &r.UpdatedAt)
    if err != nil {
        utils.Error(c, http.StatusNotFound, "room not found")
        return
    }

    utils.Success(c, http.StatusOK, r)
}

// CreateRoom godoc
// POST /api/rooms  [requires: Auth, role=admin]
func (h *RoomHandler) CreateRoom(c *gin.Context) {
    var req models.CreateRoomRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    if req.Amenities == nil {
        req.Amenities = []string{}
    }

    now := time.Now().UnixMilli()
    room := models.Room{
        ID:            uuid.New().String(),
        Name:          req.Name,
        Description:   req.Description,
        Location:      req.Location,
        City:          req.City,
        RoomClass:     req.RoomClass,
        ImageURLs:     []string{},
        Amenities:     req.Amenities,
        HasAC:         req.HasAC,
        IsAvailable:   req.IsAvailable,
        MaxGuests:     req.MaxGuests,
        ContactNumber: req.ContactNumber,
        Floor:         req.Floor,
        Building:      req.Building,
        CreatedAt:     now,
    }

    _, err := h.db.Exec(context.Background(),
        `INSERT INTO rooms (id, name, description, location, city, room_class, image_urls, amenities,
                           has_ac, is_available, max_guests, contact_number, floor, building, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
        room.ID, room.Name, room.Description, room.Location, room.City, room.RoomClass,
        room.ImageURLs, room.Amenities, room.HasAC, room.IsAvailable,
        room.MaxGuests, room.ContactNumber, room.Floor, room.Building, room.CreatedAt,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to create room")
        return
    }

    utils.Success(c, http.StatusCreated, room)
}

// UpdateRoom godoc
// PUT /api/rooms/:id  [requires: Auth, role=admin]
func (h *RoomHandler) UpdateRoom(c *gin.Context) {
    id := c.Param("id")

    var req models.UpdateRoomRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.Error(c, http.StatusBadRequest, err.Error())
        return
    }

    now := time.Now().UnixMilli()
    _, err := h.db.Exec(context.Background(),
        `UPDATE rooms SET
            name           = COALESCE($1, name),
            description    = COALESCE($2, description),
            location       = COALESCE($3, location),
            city           = COALESCE($4, city),
            room_class     = COALESCE($5, room_class),
            amenities      = COALESCE($6, amenities),
            has_ac         = COALESCE($7, has_ac),
            is_available   = COALESCE($8, is_available),
            max_guests     = COALESCE($9, max_guests),
            contact_number = COALESCE($10, contact_number),
            floor          = COALESCE($11, floor),
            building       = COALESCE($12, building),
            updated_at     = $13
         WHERE id = $14`,
        req.Name, req.Description, req.Location, req.City, req.RoomClass,
        req.Amenities, req.HasAC, req.IsAvailable, req.MaxGuests,
        req.ContactNumber, req.Floor, req.Building, now, id,
    )
    if err != nil {
        utils.Error(c, http.StatusInternalServerError, "failed to update room")
        return
    }

    // Return updated room
    h.GetRoom(c)
}

// DeleteRoom godoc
// DELETE /api/rooms/:id  [requires: Auth, role=admin]
func (h *RoomHandler) DeleteRoom(c *gin.Context) {
    id := c.Param("id")

    result, err := h.db.Exec(context.Background(),
        "DELETE FROM rooms WHERE id = $1", id)
    if err != nil || result.RowsAffected() == 0 {
        utils.Error(c, http.StatusNotFound, "room not found")
        return
    }

    utils.SuccessMessage(c, http.StatusOK, "room deleted", nil)
}

// helper untuk build dynamic query index string
func itoa(n int) string {
    return strconv.Itoa(n)
}
```

## Registrasi Routes

Di `internal/server/router.go`:

```go
import "strconv"

roomH := handlers.NewRoomHandler(db)
adminMiddleware := middleware.RequireRole("admin")

rooms := r.Group("/api/rooms")
{
    rooms.GET("", roomH.ListRooms)
    rooms.GET("/:id", roomH.GetRoom)

    // Admin-only routes
    rooms.POST("", authMiddleware, adminMiddleware, roomH.CreateRoom)
    rooms.PUT("/:id", authMiddleware, adminMiddleware, roomH.UpdateRoom)
    rooms.DELETE("/:id", authMiddleware, adminMiddleware, roomH.DeleteRoom)
}
```

## Testing dengan cURL

```bash
# List semua rooms
curl http://localhost:8080/api/rooms

# Filter by city
curl "http://localhost:8080/api/rooms?city=Jakarta&available=true"

# Search
curl "http://localhost:8080/api/rooms?search=meeting&minGuests=10"

# Get room by ID
curl http://localhost:8080/api/rooms/{room-id}

# Create room (admin)
curl -X POST http://localhost:8080/api/rooms \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ruang Rapat A",
    "description": "Ruang rapat kapasitas 10 orang",
    "location": "Gedung A, Lantai 3",
    "city": "Jakarta",
    "roomClass": "Meeting Room",
    "amenities": ["Projector", "Whiteboard"],
    "hasAC": true,
    "isAvailable": true,
    "maxGuests": 10,
    "contactNumber": "021-12345678"
  }'
```
