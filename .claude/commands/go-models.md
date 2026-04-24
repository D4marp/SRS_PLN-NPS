# Go Models

Buat Go data models untuk backend Bookify Rooms. Models ini merupakan konversi langsung dari Flutter models ke Go structs, dengan penambahan role `superadmin` dan status `rejected` untuk approval flow.

## Role Hierarchy

```
superadmin  >  admin  >  booking  >  user
```

## Booking Status Flow

```
pending → confirmed (approve) | rejected (reject)
confirmed → cancelled | completed
```

## Referensi Flutter Models

- `lib/models/user_model.dart` — UserModel, UserRole enum
- `lib/models/room_model.dart` — RoomModel
- `lib/models/booking_model.dart` — BookingModel, BookingStatus enum

## Tugas

Buat file-file berikut di `backend/internal/models/`:

### `internal/models/user.go`

```go
package models

// UserRole defines the role of a user in the system
type UserRole string

const (
    RoleUser       UserRole = "user"
    RoleBooking    UserRole = "booking"    // petugas booking desk / kiosk
    RoleAdmin      UserRole = "admin"      // approve/reject bookings, kelola rooms
    RoleSuperAdmin UserRole = "superadmin" // kelola users, promosi/demosi admin
)

// ValidRoles daftar role yang valid untuk validasi input
var ValidRoles = map[UserRole]bool{
    RoleUser: true, RoleBooking: true,
    RoleAdmin: true, RoleSuperAdmin: true,
}

// User represents a registered user (maps to: users table)
type User struct {
    ID           string   `json:"id" db:"id"`
    Name         string   `json:"name" db:"name"`
    Email        string   `json:"email" db:"email"`
    Password     string   `json:"-" db:"password"`       // never exposed in JSON
    ProfileImage *string  `json:"profileImage" db:"profile_image"`
    City         *string  `json:"city" db:"city"`
    Role         UserRole `json:"role" db:"role"`
    CreatedAt    int64    `json:"createdAt" db:"created_at"`
    UpdatedAt    *int64   `json:"updatedAt" db:"updated_at"`
}

func (u *User) IsSuperAdmin() bool { return u.Role == RoleSuperAdmin }
func (u *User) IsAdmin() bool      { return u.Role == RoleAdmin || u.Role == RoleSuperAdmin }
func (u *User) IsBooking() bool    { return u.Role == RoleBooking }

// UserResponse is the public view of User (no password)
type UserResponse struct {
    ID           string   `json:"id"`
    Name         string   `json:"name"`
    Email        string   `json:"email"`
    ProfileImage *string  `json:"profileImage"`
    City         *string  `json:"city"`
    Role         UserRole `json:"role"`
    CreatedAt    int64    `json:"createdAt"`
    UpdatedAt    *int64   `json:"updatedAt"`
}

func (u *User) ToResponse() UserResponse {
    return UserResponse{
        ID: u.ID, Name: u.Name, Email: u.Email,
        ProfileImage: u.ProfileImage, City: u.City,
        Role: u.Role, CreatedAt: u.CreatedAt, UpdatedAt: u.UpdatedAt,
    }
}

// RegisterRequest untuk POST /api/auth/register
type RegisterRequest struct {
    Name     string `json:"name" binding:"required,min=2,max=100"`
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required,min=6"`
}

// LoginRequest untuk POST /api/auth/login
type LoginRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required"`
}

// UpdateUserRequest untuk PUT /api/auth/me
type UpdateUserRequest struct {
    Name         *string `json:"name"`
    ProfileImage *string `json:"profileImage"`
    City         *string `json:"city"`
}

// UpdateCityRequest untuk PATCH /api/auth/me/city (GPS update dari Flutter)
type UpdateCityRequest struct {
    City string `json:"city" binding:"required"`
}

// AuthResponse dikembalikan setelah login/register berhasil
type AuthResponse struct {
    Token string       `json:"token"`
    User  UserResponse `json:"user"`
}

// ChangeRoleRequest untuk PATCH /api/admin/users/:id/role (superadmin only)
type ChangeRoleRequest struct {
    Role UserRole `json:"role" binding:"required"`
}

// UserListFilter untuk GET /api/admin/users (superadmin)
type UserListFilter struct {
    Role   UserRole `form:"role"`
    Search string   `form:"search"`
}
```

### `internal/models/room.go`

```go
package models

// RoomClass defines the type/class of a room
type RoomClass string

const (
    RoomClassMeeting     RoomClass = "Meeting Room"
    RoomClassConference  RoomClass = "Conference Room"
    RoomClassAuditorium  RoomClass = "Auditorium"
    RoomClassStudy       RoomClass = "Study Room"
    RoomClassTraining    RoomClass = "Training Room"
    RoomClassBoard       RoomClass = "Board Room"
    RoomClassBoardroom   RoomClass = "Boardroom"
    RoomClassOffice      RoomClass = "Office"
    RoomClassClassRoom   RoomClass = "Class Room"
    RoomClassLab         RoomClass = "Lab"
    RoomClassLectureHall RoomClass = "Lecture Hall"
)

// Room represents a bookable room (maps to: rooms table)
type Room struct {
    ID            string    `json:"id" db:"id"`
    Name          string    `json:"name" db:"name"`
    Description   string    `json:"description" db:"description"`
    Location      string    `json:"location" db:"location"`
    City          string    `json:"city" db:"city"`
    RoomClass     RoomClass `json:"roomClass" db:"room_class"`
    ImageURLs     []string  `json:"imageUrls" db:"image_urls"`
    Amenities     []string  `json:"amenities" db:"amenities"`
    HasAC         bool      `json:"hasAC" db:"has_ac"`
    IsAvailable   bool      `json:"isAvailable" db:"is_available"`
    MaxGuests     int       `json:"maxGuests" db:"max_guests"`
    ContactNumber string    `json:"contactNumber" db:"contact_number"`
    Floor         *string   `json:"floor" db:"floor"`
    Building      *string   `json:"building" db:"building"`
    CreatedAt     int64     `json:"createdAt" db:"created_at"`
    UpdatedAt     *int64    `json:"updatedAt" db:"updated_at"`
}

// CreateRoomRequest untuk POST /api/rooms (admin/superadmin only)
type CreateRoomRequest struct {
    Name          string    `json:"name" binding:"required,min=2,max=255"`
    Description   string    `json:"description" binding:"required"`
    Location      string    `json:"location" binding:"required"`
    City          string    `json:"city" binding:"required"`
    RoomClass     RoomClass `json:"roomClass" binding:"required"`
    Amenities     []string  `json:"amenities"`
    HasAC         bool      `json:"hasAC"`
    IsAvailable   bool      `json:"isAvailable"`
    MaxGuests     int       `json:"maxGuests" binding:"required,min=1"`
    ContactNumber string    `json:"contactNumber" binding:"required"`
    Floor         *string   `json:"floor"`
    Building      *string   `json:"building"`
}

// UpdateRoomRequest untuk PUT /api/rooms/:id (admin/superadmin only)
type UpdateRoomRequest struct {
    Name          *string    `json:"name"`
    Description   *string    `json:"description"`
    Location      *string    `json:"location"`
    City          *string    `json:"city"`
    RoomClass     *RoomClass `json:"roomClass"`
    Amenities     []string   `json:"amenities"`
    HasAC         *bool      `json:"hasAC"`
    IsAvailable   *bool      `json:"isAvailable"`
    MaxGuests     *int       `json:"maxGuests"`
    ContactNumber *string    `json:"contactNumber"`
    Floor         *string    `json:"floor"`
    Building      *string    `json:"building"`
}

// RoomFilter untuk GET /api/rooms query params
type RoomFilter struct {
    City      string    `form:"city"`
    RoomClass RoomClass `form:"roomClass"`
    HasAC     *bool     `form:"hasAC"`
    MinGuests *int      `form:"minGuests"`
    Search    string    `form:"search"`
    Available *bool     `form:"available"`
}
```

### `internal/models/booking.go`

```go
package models

// BookingStatus defines the lifecycle status of a booking
type BookingStatus string

const (
    // StatusPending: default saat user buat booking, menunggu approval admin
    StatusPending   BookingStatus = "pending"
    // StatusConfirmed: admin sudah approve
    StatusConfirmed BookingStatus = "confirmed"
    // StatusRejected: admin tolak booking, ada rejection_reason
    StatusRejected  BookingStatus = "rejected"
    // StatusCancelled: user atau admin cancel booking yang sudah confirmed
    StatusCancelled BookingStatus = "cancelled"
    // StatusCompleted: admin mark booking sebagai selesai
    StatusCompleted BookingStatus = "completed"
)

// Booking represents a room reservation (maps to: bookings table)
// Denormalized fields (roomName, userName, etc.) dipertahankan untuk
// kompatibilitas dengan Flutter app yang sudah ada.
type Booking struct {
    ID              string        `json:"id" db:"id"`
    UserID          string        `json:"userId" db:"user_id"`
    RoomID          string        `json:"roomId" db:"room_id"`
    BookingDate     int64         `json:"bookingDate" db:"booking_date"`
    CheckInTime     string        `json:"checkInTime" db:"check_in_time"`
    CheckOutTime    string        `json:"checkOutTime" db:"check_out_time"`
    NumberOfGuests  int           `json:"numberOfGuests" db:"number_of_guests"`
    Status          BookingStatus `json:"status" db:"status"`
    Purpose         *string       `json:"purpose" db:"purpose"`
    // Approval fields
    RejectionReason *string       `json:"rejectionReason" db:"rejection_reason"`
    ApprovedBy      *string       `json:"approvedBy" db:"approved_by"`   // user_id reviewer
    ApprovedAt      *int64        `json:"approvedAt" db:"approved_at"`
    // Denormalized fields (same as Firestore behavior)
    RoomName        *string       `json:"roomName" db:"room_name"`
    RoomLocation    *string       `json:"roomLocation" db:"room_location"`
    RoomImageURL    *string       `json:"roomImageUrl" db:"room_image_url"`
    UserName        *string       `json:"userName" db:"user_name"`
    UserEmail       *string       `json:"userEmail" db:"user_email"`
    CreatedAt       int64         `json:"createdAt" db:"created_at"`
    UpdatedAt       *int64        `json:"updatedAt" db:"updated_at"`
}

// CreateBookingRequest untuk POST /api/bookings
type CreateBookingRequest struct {
    RoomID         string  `json:"roomId" binding:"required"`
    BookingDate    int64   `json:"bookingDate" binding:"required"`
    CheckInTime    string  `json:"checkInTime" binding:"required"`   // "HH:mm"
    CheckOutTime   string  `json:"checkOutTime" binding:"required"`  // "HH:mm"
    NumberOfGuests int     `json:"numberOfGuests" binding:"required,min=1"`
    Purpose        *string `json:"purpose"`
}

// ApproveBookingRequest untuk POST /api/bookings/:id/approve (admin/superadmin)
// Tidak perlu body, tapi struct ini ready jika diperlukan note
type ApproveBookingRequest struct {
    Note *string `json:"note"` // opsional catatan dari admin
}

// RejectBookingRequest untuk POST /api/bookings/:id/reject (admin/superadmin)
type RejectBookingRequest struct {
    Reason string `json:"reason" binding:"required,min=5"` // wajib diisi alasan penolakan
}

// BookingFilter untuk GET /api/bookings query params
type BookingFilter struct {
    UserID string        `form:"userId"`
    RoomID string        `form:"roomId"`
    Status BookingStatus `form:"status"`
}

// BookingStatusHistory untuk table booking_status_history (audit trail)
type BookingStatusHistory struct {
    ID         string `json:"id"`
    BookingID  string `json:"bookingId"`
    FromStatus string `json:"fromStatus"`
    ToStatus   string `json:"toStatus"`
    ChangedBy  string `json:"changedBy"`  // user_id
    Note       string `json:"note"`
    CreatedAt  int64  `json:"createdAt"`
}
```

### `internal/models/pagination.go`

```go
package models

// PaginatedResponse wraps a list response with pagination metadata
type PaginatedResponse struct {
    Data       interface{} `json:"data"`
    Total      int         `json:"total"`
    Page       int         `json:"page"`
    PageSize   int         `json:"pageSize"`
    TotalPages int         `json:"totalPages"`
}

// PaginationQuery untuk extract pagination params dari query string
type PaginationQuery struct {
    Page     int `form:"page,default=1"`
    PageSize int `form:"pageSize,default=20"`
}

func (p *PaginationQuery) Offset() int {
    if p.Page < 1 {
        p.Page = 1
    }
    return (p.Page - 1) * p.PageSize
}
```

## Verifikasi

Setelah semua file dibuat:
```bash
go build ./internal/models/...
```

## Catatan Penting

- `IsAdmin()` mengembalikan `true` untuk KEDUANYA `admin` DAN `superadmin` — superadmin otomatis bisa melakukan semua yang bisa dilakukan admin.
- Field `Password` menggunakan `json:"-"` sehingga **tidak pernah** terekspos di response.
- `RejectionReason` wajib diisi saat admin reject (enforced di handler), agar user tahu alasannya.
- `ApprovedBy` menyimpan `user_id` admin yang approve/reject — berguna untuk audit trail.
- `booking_status_history` table menyimpan semua perubahan status sebagai audit log.
