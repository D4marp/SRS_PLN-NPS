# Firebase Firestore Setup Guide

## Composite Index Error Fix

Jika Anda mendapatkan error seperti:
```
[cloud_firestore/failed-precondition] The query requires an index.
```

### Solusi 1: Menggunakan Link dari Error Message (RECOMMENDED)

1. Copy link yang ada di error message
2. Paste ke browser Anda
3. Klik tombol "Create Index" di Firebase Console
4. Tunggu beberapa menit hingga index selesai dibuat
5. Refresh aplikasi

### Solusi 2: Manual Setup di Firebase Console

#### Step 1: Buka Firebase Console
- Kunjungi: https://console.firebase.google.com
- Pilih project: `booking-room-system1`
- Buka **Firestore Database**

#### Step 2: Pergi ke Indexes
- Klik tab **Indexes**
- Cari bagian **Composite Indexes**

#### Step 3: Buat Composite Index untuk User Bookings
Jika belum ada index untuk query user bookings, buat index dengan:
- **Collection**: `bookings`
- **Fields**:
  - `userId` (Ascending)
  - `createdAt` (Descending)

## Optimization Changes

Kami telah mengoptimalkan query untuk mengurangi kebutuhan composite index:

### getUserBookings Query
**Sebelum (Perlu Composite Index):**
```dart
.where('userId', isEqualTo: userId)
.orderBy('createdAt', descending: true)
```

**Sesudah (No Index Required):**
```dart
.where('userId', isEqualTo: userId)
// Sort di client-side
bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
```

### isTimeSlotAvailable Query
**Sebelum (Perlu Composite Index):**
```dart
.where('roomId', isEqualTo: roomId)
.where('checkInDate', isLessThanOrEqualTo: ...)
.where('checkOutDate', isGreaterThanOrEqualTo: ...)
.where('status', whereIn: ['pending', 'confirmed'])
```

**Sesudah (No Index Required):**
```dart
.where('roomId', isEqualTo: roomId)
// Filter date dan status di client-side
```

## Firestore Security Rules

Pastikan security rules sudah di-setup dengan benar. Berikut rules yang optimal untuk aplikasi:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - only user can read/write own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Rooms collection - anyone can read, only admins can write
    match /rooms/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Bookings collection - all authenticated users can READ all bookings
    // Users can CREATE their own, UPDATE/DELETE only their own
    match /bookings/{bookingId} {
      // ALL authenticated users can read all bookings (to see room schedules)
      allow read: if request.auth != null;
      
      // Users can create bookings (must use their own userId)
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      
      // Users can update/delete only their own bookings, admins can do both
      allow update, delete: if request.auth != null && 
                               (resource.data.userId == request.auth.uid || 
                                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Block everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Rule Explanations:

**Users Collection:**
- ✅ Users hanya bisa read/write data mereka sendiri
- 🔒 Data user lain tidak bisa diakses

**Rooms Collection:**
- ✅ Siapa saja bisa read rooms (public data)
- 🔒 Hanya admin yang bisa create/update/delete rooms

**Bookings Collection:**
- ✅ User authenticated bisa read semua bookings (untuk lihat schedule room)
- ✅ User bisa create booking dengan userId mereka sendiri
- ✅ User hanya bisa update/delete booking mereka sendiri
- ✅ Admin bisa update/delete semua bookings
- 🔒 Anonymous users tidak bisa akses

### Cara Set Rules di Firebase Console:

1. Buka https://console.firebase.google.com
2. Pilih project: `booking-room-system1`
3. Klik **Firestore Database**
4. Klik tab **Rules**
5. Copy-paste rules di atas
6. Klik **Publish**

## Firestore Collection Structure

### Users Collection
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user",  // "user", "booking", "admin"
  "phone": "08123456789",
  "profileImageUrl": "https://...",
  "createdAt": 1703001600000,
  "updatedAt": 1703001600000
}
```

### Rooms Collection
```json
{
  "name": "Conference Room A",
  "description": "Large conference room with AC",
  "location": "3rd Floor, Building A",
  "city": "Jakarta",
  "roomClass": "Meeting Room",
  "floor": "3",
  "building": "A",
  "imageUrls": ["https://..."],
  "amenities": ["Projector", "AC", "Whiteboard"],
  "hasAC": true,
  "maxGuests": 20,
  "contactNumber": "021-1234567",
  "isAvailable": true,
  "createdAt": 1703001600000,
  "updatedAt": 1703001600000
}
```

### Bookings Collection
```json
{
  "userId": "user-id-here",
  "roomId": "room-id-here",
  "userName": "John Doe",
  "userEmail": "user@example.com",
  "roomName": "Conference Room A",
  "roomLocation": "3rd Floor",
  "roomImageUrl": "https://...",
  "bookingDate": 1703001600000,
  "checkInTime": "09:00",
  "checkOutTime": "11:00",
  "numberOfGuests": 10,
  "purpose": "Team Meeting",
  "status": "confirmed",  // "pending", "confirmed", "cancelled", "completed"
  "createdAt": 1703001600000,
  "updatedAt": 1703001600000
}
```

### Field Types & Validation:
- **Timestamps**: Milliseconds since epoch (use `DateTime.now().millisecondsSinceEpoch`)
- **Times**: String format "HH:mm" (e.g., "09:00", "14:30")
- **Role**: Must be one of: "user", "booking", "admin"
- **Status**: Must be one of: "pending", "confirmed", "cancelled", "completed"

## Common Issues & Solutions

### Issue 1: "Permission Denied" when Reading Bookings
**Cause:** User tidak terautentikasi atau rules belum di-publish

**Solution:**
- Pastikan user sudah login dengan benar
- Check di Firebase Console → Authentication
- Publish security rules baru
- Test rules dengan simulasi di Firebase Console

### Issue 2: "Create Booking" Fails
**Cause:** userId di request tidak match dengan authenticated user

**Solution:**
```dart
// BENAR ✅
final bookingId = await BookingService.createBooking(
  userId: authProvider.user!.uid,  // Use authenticated user ID
  roomId: roomId,
  ...
);

// SALAH ❌
final bookingId = await BookingService.createBooking(
  userId: "other-user-id",  // This will fail!
  roomId: roomId,
  ...
);
```

### Issue 3: Admin Cannot Edit User's Booking
**Cause:** Admin role not set correctly in users collection

**Solution:**
- Go to Firebase Console
- Find user document in `/users` collection
- Set `role: "admin"`
- Admin akan bisa update/delete semua bookings

## Query Optimization Tips

### ✅ DO - Optimized Queries
```dart
// Single where clause - no index needed
.where('userId', isEqualTo: userId)

// Single collection read
.collection('bookings').snapshots()

// Filter/sort di client-side
bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
```

### ❌ DON'T - Requires Composite Index
```dart
// Multiple where + orderBy - needs composite index
.where('userId', isEqualTo: userId)
.where('status', isEqualTo: 'confirmed')
.orderBy('createdAt', descending: true)

// Multiple inequality filters - not allowed
.where('createdAt', isGreaterThan: date1)
.where('updatedAt', isLessThan: date2)
```

## Realtime Updates

Aplikasi ini menggunakan Firestore Streams untuk realtime updates:
- Data otomatis tersinkronisasi di semua device
- Tidak perlu manual refresh
- Perubahan muncul dalam waktu < 1 detik

## Troubleshooting

### Error: "Permission Denied"
- Check Firestore security rules
- Pastikan user sudah login
- Verifikasi user ID di database

### Error: "Missing Collection"
- Pastikan collection `bookings` sudah ada di Firestore
- Buat booking pertama untuk membuat collection

### Data Tidak Update Realtime
- Check internet connection
- Pastikan Firestore rules mengizinkan read access
- Restart aplikasi

## Contacts & Support

Untuk bantuan setup Firebase:
- Baca dokumentasi: https://firebase.google.com/docs/firestore
- Hubungi Firebase Support: https://firebase.google.com/support
