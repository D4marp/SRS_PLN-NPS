# Go Realtime

Implementasikan WebSocket server di Go untuk menggantikan Firestore real-time streams (`snapshots()`).

## Pemetaan dari Firestore Streams

| Firestore Stream | WebSocket Channel |
|-----------------|-------------------|
| `rooms.snapshots()` (all rooms) | `WS /ws/rooms` |
| `rooms.where('city',...).snapshots()` | `WS /ws/rooms?city=Jakarta` |
| `bookings.where('userId',...).snapshots()` | `WS /ws/bookings?userId=xxx` |
| `bookings.orderBy('createdAt').snapshots()` (admin) | `WS /ws/bookings` (admin only) |
| `bookings.where('roomId',...).snapshots()` | `WS /ws/rooms/:id/bookings` |

## Architecture

```
Flutter App                     Go Backend
    |                               |
    |-- WS Connect /ws/rooms -----> Hub
    |                               |
    |                           RoomHub.Subscribe(conn)
    |                               |
    |<-- BroadcastMessage (rooms) --|
    |                               |
    |   (admin creates a room)      |
    |-- POST /api/rooms ----------> RoomHandler.CreateRoom()
    |                               |-- RoomHub.Broadcast(updatedRooms)
    |<-- WS: updated room list -----|
```

## Tugas

### 1. Buat `internal/realtime/hub.go`

```go
package realtime

import (
    "encoding/json"
    "sync"

    "github.com/gorilla/websocket"
)

// Client represents a WebSocket connection
type Client struct {
    conn   *websocket.Conn
    send   chan []byte
    filter map[string]string // query params sebagai filter (e.g., {"city": "Jakarta"})
}

// Hub manages all WebSocket clients for a specific channel
type Hub struct {
    mu      sync.RWMutex
    clients map[*Client]bool
}

func NewHub() *Hub {
    return &Hub{
        clients: make(map[*Client]bool),
    }
}

func (h *Hub) Register(c *Client) {
    h.mu.Lock()
    h.clients[c] = true
    h.mu.Unlock()
}

func (h *Hub) Unregister(c *Client) {
    h.mu.Lock()
    if _, ok := h.clients[c]; ok {
        delete(h.clients, c)
        close(c.send)
    }
    h.mu.Unlock()
}

// Broadcast kirim message ke semua connected clients
// Jika filterKey/filterValue ada, hanya kirim ke clients dengan filter yang cocok
func (h *Hub) Broadcast(payload interface{}) {
    data, err := json.Marshal(WSMessage{Type: "update", Data: payload})
    if err != nil {
        return
    }

    h.mu.RLock()
    defer h.mu.RUnlock()

    for client := range h.clients {
        select {
        case client.send <- data:
        default:
            // Client lambat / disconnected
        }
    }
}

// BroadcastFiltered hanya kirim ke clients dengan filter cocok
func (h *Hub) BroadcastFiltered(filterKey, filterValue string, payload interface{}) {
    data, err := json.Marshal(WSMessage{Type: "update", Data: payload})
    if err != nil {
        return
    }

    h.mu.RLock()
    defer h.mu.RUnlock()

    for client := range h.clients {
        if client.filter[filterKey] == filterValue || client.filter[filterKey] == "" {
            select {
            case client.send <- data:
            default:
            }
        }
    }
}

// WSMessage adalah format pesan WebSocket
type WSMessage struct {
    Type string      `json:"type"` // "update", "error", "ping"
    Data interface{} `json:"data"`
}
```

### 2. Buat `internal/realtime/manager.go`

```go
package realtime

// Manager holds all hubs untuk semua channels
type Manager struct {
    Rooms    *Hub // WS /ws/rooms
    Bookings *Hub // WS /ws/bookings
}

func NewManager() *Manager {
    return &Manager{
        Rooms:    NewHub(),
        Bookings: NewHub(),
    }
}
```

### 3. Buat `internal/handlers/ws_handler.go`

```go
package handlers

import (
    "context"
    "log"
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/gorilla/websocket"
    "github.com/jackc/pgx/v5/pgxpool"

    "github.com/bookify-rooms/backend/internal/models"
    "github.com/bookify-rooms/backend/internal/realtime"
    "github.com/bookify-rooms/backend/internal/utils"
)

var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        return true // Allow all origins untuk development
        // Production: return r.Header.Get("Origin") == "https://yourapp.com"
    },
}

type WSHandler struct {
    db      *pgxpool.Pool
    manager *realtime.Manager
    secret  string
}

func NewWSHandler(db *pgxpool.Pool, manager *realtime.Manager, jwtSecret string) *WSHandler {
    return &WSHandler{db: db, manager: manager, secret: jwtSecret}
}

// WatchRooms godoc
// WS /ws/rooms?city=Jakarta&available=true
// Client menerima broadcast setiap kali ada perubahan rooms
func (h *WSHandler) WatchRooms(c *gin.Context) {
    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        return
    }

    client := &realtime.Client{
        Conn:   conn,
        Send:   make(chan []byte, 256),
        Filter: map[string]string{
            "city":      c.Query("city"),
            "available": c.Query("available"),
        },
    }

    h.manager.Rooms.Register(client)
    defer h.manager.Rooms.Unregister(client)

    // Kirim data awal (initial state) setelah connect
    var filter models.RoomFilter
    c.ShouldBindQuery(&filter)
    rooms := h.fetchRooms(filter)
    data, _ := json.Marshal(realtime.WSMessage{Type: "initial", Data: rooms})
    conn.WriteMessage(websocket.TextMessage, data)

    // Write pump: kirim messages dari channel ke WebSocket
    go func() {
        ticker := time.NewTicker(30 * time.Second)
        defer ticker.Stop()
        for {
            select {
            case message, ok := <-client.Send:
                if !ok {
                    conn.WriteMessage(websocket.CloseMessage, []byte{})
                    return
                }
                conn.WriteMessage(websocket.TextMessage, message)
            case <-ticker.C:
                // Ping untuk keep-alive
                conn.WriteMessage(websocket.PingMessage, nil)
            }
        }
    }()

    // Read pump: terima messages dari client (umumnya hanya ping)
    for {
        _, _, err := conn.ReadMessage()
        if err != nil {
            break
        }
    }
}

// WatchBookings godoc
// WS /ws/bookings  (admin: semua bookings; user: own bookings via JWT)
func (h *WSHandler) WatchBookings(c *gin.Context) {
    // Autentikasi via query token (karena WS tidak support custom headers)
    token := c.Query("token")
    claims, err := utils.ValidateToken(token, h.secret)
    if err != nil {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
        return
    }

    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        return
    }

    client := &realtime.Client{
        Conn:   conn,
        Send:   make(chan []byte, 256),
        Filter: map[string]string{
            "userId": claims.UserID,
            "role":   claims.Role,
        },
    }

    h.manager.Bookings.Register(client)
    defer h.manager.Bookings.Unregister(client)

    // Kirim data awal
    bookings := h.fetchBookings(claims.UserID, claims.Role)
    data, _ := json.Marshal(realtime.WSMessage{Type: "initial", Data: bookings})
    conn.WriteMessage(websocket.TextMessage, data)

    // Write pump
    go func() {
        ticker := time.NewTicker(30 * time.Second)
        defer ticker.Stop()
        for {
            select {
            case message, ok := <-client.Send:
                if !ok {
                    conn.WriteMessage(websocket.CloseMessage, []byte{})
                    return
                }
                conn.WriteMessage(websocket.TextMessage, message)
            case <-ticker.C:
                conn.WriteMessage(websocket.PingMessage, nil)
            }
        }
    }()

    for {
        _, _, err := conn.ReadMessage()
        if err != nil {
            break
        }
    }
}

func (h *WSHandler) fetchRooms(filter models.RoomFilter) []models.Room {
    // Implementasi query rooms sama seperti RoomHandler.ListRooms
    // Simplified: return all rooms
    rows, err := h.db.Query(context.Background(),
        `SELECT id, name, description, location, city, room_class, image_urls, amenities,
                has_ac, is_available, max_guests, contact_number, floor, building,
                created_at, updated_at FROM rooms ORDER BY created_at DESC`)
    if err != nil {
        return []models.Room{}
    }
    defer rows.Close()

    rooms := []models.Room{}
    for rows.Next() {
        var r models.Room
        rows.Scan(&r.ID, &r.Name, &r.Description, &r.Location, &r.City, &r.RoomClass,
            &r.ImageURLs, &r.Amenities, &r.HasAC, &r.IsAvailable,
            &r.MaxGuests, &r.ContactNumber, &r.Floor, &r.Building,
            &r.CreatedAt, &r.UpdatedAt)
        rooms = append(rooms, r)
    }
    return rooms
}

func (h *WSHandler) fetchBookings(userID, role string) []models.Booking {
    query := `SELECT id, user_id, room_id, booking_date, check_in_time, check_out_time,
                     number_of_guests, status, purpose,
                     room_name, room_location, room_image_url, user_name, user_email,
                     created_at, updated_at FROM bookings`
    args := []interface{}{}

    if role != "admin" {
        query += ` WHERE user_id = $1`
        args = append(args, userID)
    }
    query += ` ORDER BY created_at DESC`

    rows, err := h.db.Query(context.Background(), query, args...)
    if err != nil {
        return []models.Booking{}
    }
    defer rows.Close()

    bookings := []models.Booking{}
    for rows.Next() {
        var b models.Booking
        rows.Scan(&b.ID, &b.UserID, &b.RoomID, &b.BookingDate,
            &b.CheckInTime, &b.CheckOutTime, &b.NumberOfGuests,
            &b.Status, &b.Purpose,
            &b.RoomName, &b.RoomLocation, &b.RoomImageURL,
            &b.UserName, &b.UserEmail,
            &b.CreatedAt, &b.UpdatedAt)
        bookings = append(bookings, b)
    }
    return bookings
}
```

### 4. Install dependency WebSocket

```bash
go get github.com/gorilla/websocket@latest
```

### 5. Broadcast setelah mutations

Di setiap handler yang mengubah data, tambahkan broadcast ke hub:

**Di `room_handler.go`** (inject `*realtime.Manager`):
```go
// Setelah successful create/update/delete:
go manager.Rooms.Broadcast(/* updated rooms list */)
```

**Di `booking_handler.go`** (inject `*realtime.Manager`):
```go
// Setelah successful create/cancel:
go manager.Bookings.Broadcast(/* updated bookings */)
```

### 6. Registrasi WS Routes

```go
wsH := handlers.NewWSHandler(db, rtManager, cfg.JWTSecret)

r.GET("/ws/rooms", wsH.WatchRooms)
r.GET("/ws/bookings", wsH.WatchBookings)  // token via query param
```

## Flutter App Changes

Di Flutter, ganti Firestore streams dengan WebSocket:

```dart
// Tambah dependency di pubspec.yaml:
// web_socket_channel: ^3.0.0

import 'package:web_socket_channel/web_socket_channel.dart';

// Ganti:
// FirebaseFirestore.instance.collection('rooms').snapshots()
// Dengan:
final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8080/ws/rooms?city=$city'),
);
channel.stream.listen((data) {
  final msg = jsonDecode(data);
  if (msg['type'] == 'initial' || msg['type'] == 'update') {
    final rooms = (msg['data'] as List).map((r) => RoomModel.fromJson(r)).toList();
    // update state
  }
});
```

## Alternatif: Server-Sent Events (SSE)

Jika WebSocket terlalu complex, bisa gunakan SSE sebagai alternatif lebih sederhana:

```go
// GET /api/rooms/stream
func (h *RoomHandler) StreamRooms(c *gin.Context) {
    c.Header("Content-Type", "text/event-stream")
    c.Header("Cache-Control", "no-cache")
    c.Header("Connection", "keep-alive")

    ticker := time.NewTicker(3 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            rooms := h.fetchAllRooms()
            data, _ := json.Marshal(rooms)
            c.SSEvent("rooms", string(data))
            c.Writer.Flush()
        case <-c.Request.Context().Done():
            return
        }
    }
}
```

SSE lebih mudah diimplementasikan dan Flutter mendukungnya via `http` package dengan streaming response.
