package models

// BookingStatus defines the lifecycle status of a booking
type BookingStatus string

const (
	// StatusPending: default saat user buat booking, menunggu approval admin
	StatusPending BookingStatus = "pending"
	// StatusConfirmed: admin sudah approve
	StatusConfirmed BookingStatus = "confirmed"
	// StatusRejected: admin tolak booking, disertai rejection_reason
	StatusRejected BookingStatus = "rejected"
	// StatusCancelled: user atau admin cancel booking yang pending/confirmed
	StatusCancelled BookingStatus = "cancelled"
	// StatusCompleted: admin mark booking sebagai selesai
	StatusCompleted BookingStatus = "completed"
)

// Booking represents a room reservation
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
	RejectionReason *string       `json:"rejectionReason" db:"rejection_reason"`
	ApprovedBy      *string       `json:"approvedBy" db:"approved_by"`
	ApprovedAt      *int64        `json:"approvedAt" db:"approved_at"`
	// Denormalized fields (same as Firestore behavior)
	RoomName     *string `json:"roomName" db:"room_name"`
	RoomLocation *string `json:"roomLocation" db:"room_location"`
	RoomImageURL *string `json:"roomImageUrl" db:"room_image_url"`
	UserName     *string `json:"userName" db:"user_name"`
	UserEmail    *string `json:"userEmail" db:"user_email"`
	CreatedAt    int64   `json:"createdAt" db:"created_at"`
	UpdatedAt    *int64  `json:"updatedAt" db:"updated_at"`
}

type CreateBookingRequest struct {
	RoomID         string  `json:"roomId" binding:"required"`
	BookingDate    int64   `json:"bookingDate" binding:"required"`
	CheckInTime    string  `json:"checkInTime" binding:"required"`
	CheckOutTime   string  `json:"checkOutTime" binding:"required"`
	NumberOfGuests int     `json:"numberOfGuests" binding:"required,min=1"`
	Purpose        *string `json:"purpose"`
}

type ApproveBookingRequest struct {
	Note *string `json:"note"`
}

type RejectBookingRequest struct {
	Reason string `json:"reason" binding:"required,min=5"`
}

type BookingFilter struct {
	UserID string        `form:"userId"`
	RoomID string        `form:"roomId"`
	Status BookingStatus `form:"status"`
}

type BookingStatusHistory struct {
	ID         string `json:"id" db:"id"`
	BookingID  string `json:"bookingId" db:"booking_id"`
	FromStatus string `json:"fromStatus" db:"from_status"`
	ToStatus   string `json:"toStatus" db:"to_status"`
	ChangedBy  string `json:"changedBy" db:"changed_by"`
	Note       string `json:"note" db:"note"`
	CreatedAt  int64  `json:"createdAt" db:"created_at"`
}
