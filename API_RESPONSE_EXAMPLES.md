# API Response Examples & Data Structures

## Authentication

### POST /api/auth/register
```json
{
  "success": true,
  "message": "registration successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "4b91a104-f5c6-4563-b35a-5c294fcd0f73",
      "name": "Test Admin",
      "email": "admin@test.local",
      "profileImage": null,
      "city": null,
      "role": "user",
      "createdAt": 1777021096061,
      "updatedAt": null
    }
  }
}
```

### POST /api/auth/login
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "4b91a104-f5c6-4563-b35a-5c294fcd0f73",
      "name": "Test Admin",
      "email": "admin@test.local",
      "role": "admin",
      ...
    }
  }
}
```

---

## Admin Endpoints (Requires: Authorization Header + admin role)

### GET /api/admin/stats
Returns statistics for dashboard
```json
{
  "success": true,
  "data": {
    "bookings": {
      "cancelled": 0,
      "completed": 0,
      "confirmed": 0,
      "pending": 0,
      "rejected": 0,
      "total": 0
    },
    "rooms": {
      "available": 0,
      "total": 0
    },
    "users": {
      "admins": 1,
      "booking": 0,
      "total": 0
    }
  }
}
```

**Flutter Usage**:
```dart
// In AdminProvider
int get totalBookings => _stats['total_bookings'] as int? ?? 0;
int get confirmedCount => (_stats['bookings'] as Map)?['confirmed'] as int? ?? 0;
int get pendingCount => _pendingCount;
int get totalRooms => _stats['total_rooms'] as int? ?? 0;
```

### GET /api/admin/bookings [?status=pending]
Returns bookings list, optionally filtered by status
```json
{
  "success": true,
  "data": [
    {
      "id": "booking-123",
      "userId": "user-456",
      "roomId": "room-789",
      "bookingDate": 1777020000000,
      "checkInTime": "14:00",
      "checkOutTime": "17:00",
      "numberOfGuests": 5,
      "status": "pending",
      "createdAt": 1777020000000,
      "updatedAt": null,
      "purpose": "Team Meeting",
      "rejectionReason": null,
      "approvedBy": null,
      "approvedAt": null,
      "roomName": "Conference Room A",
      "roomLocation": "Building 2, Floor 3",
      "roomImageUrl": "https://...",
      "userName": "John Doe",
      "userEmail": "john@example.com"
    }
  ]
}
```

**Query Parameters**:
- `status=pending` - Filter by status
- `status=confirmed`
- `status=rejected`
- `status=cancelled`
- `status=completed`

**Flutter Usage**:
```dart
// In BookingCalendarScreen
List<BookingModel> _getBookingsForDay(DateTime day) {
  return _bookingsByDate[DateTime(day.year, day.month, day.day)] ?? [];
}

// Parse API response
List<BookingModel> bookings = response.map(
  (e) => BookingModel.fromJson(Map<String, dynamic>.from(e))
).toList();
```

---

## Public Endpoints (No Auth Required)

### GET /api/rooms
```json
{
  "success": true,
  "data": [
    {
      "id": "room-123",
      "name": "Conference Room A",
      "description": "Large meeting room with video conference setup",
      "capacity": 20,
      "city": "Jakarta",
      "roomClass": "Premium",
      "amenities": ["WiFi", "Projector", "Whiteboard", "Air Conditioning"],
      "imageUrls": ["https://...image1.jpg", "https://...image2.jpg"],
      "pricePerHour": 50000,
      "isAvailable": true,
      "createdAt": 1777020000000,
      "updatedAt": null
    }
  ]
}
```

---

## Error Responses

### Unauthorized (No Token)
```json
{
  "success": false,
  "error": "unauthorized"
}
```

### Forbidden (Non-Admin User)
```json
{
  "success": false,
  "error": "forbidden: requires role admin or superadmin"
}
```

### Bad Request
```json
{
  "success": false,
  "error": "invalid request",
  "fieldsErrors": {
    "email": "email is required",
    "password": "password must be at least 8 characters"
  }
}
```

---

## Request Headers Required

### For Protected Endpoints
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

### Example curl command
```bash
curl -X GET http://localhost:8080/api/admin/stats \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json"
```

---

## BookingModel Mapping
```dart
class BookingModel {
  final String id;
  final String userId;
  final String roomId;
  final DateTime bookingDate;       // from: bookingDate (timestamp)
  final String checkInTime;         // "14:00"
  final String checkOutTime;        // "17:00"
  final int numberOfGuests;
  final BookingStatus status;       // pending|confirmed|rejected|cancelled|completed
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? purpose;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;

  // Display fields
  final String? roomName;
  final String? roomLocation;
  final String? roomImageUrl;
  final String? userName;
  final String? userEmail;
}
```

---

## BookingStatus Enum
```dart
enum BookingStatus {
  pending,      // Awaiting admin approval
  confirmed,    // Approved by admin
  rejected,     // Denied by admin
  cancelled,    // User cancelled
  completed,    // Booking completed
}

// Status Colors in Dashboard
pending   → Amber (#F59E0B)
confirmed → Green (#16A34A)
rejected  → Red (#DC2626)
cancelled → Gray (#6B7280)
completed → Blue (#0EA5E9)
```

---

## Testing Steps (Manual Verification)

1. **Start Backend**
   ```bash
   cd backend && go run ./cmd/server/
   ```

2. **Create Admin User**
   ```bash
   curl -X POST http://localhost:8080/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@test.local","password":"Admin@123456","name":"Admin","phone":"081234567890","company":"Test","city":"Jakarta"}'
   ```

3. **Change Role to Admin** (use superadmin token)
   ```bash
   curl -X PATCH http://localhost:8080/api/admin/users/{userId}/role \
     -H "Authorization: Bearer {superadmin_token}" \
     -H "Content-Type: application/json" \
     -d '{"role":"admin"}'
   ```

4. **Test Stats**
   ```bash
   curl -X GET http://localhost:8080/api/admin/stats \
     -H "Authorization: Bearer {admin_token}"
   ```

5. **Test Bookings**
   ```bash
   curl -X GET http://localhost:8080/api/admin/bookings \
     -H "Authorization: Bearer {admin_token}"
   ```
