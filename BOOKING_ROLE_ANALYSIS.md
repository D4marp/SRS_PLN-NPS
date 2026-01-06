# Analisis Penggunaan Role "Booking" dalam Aplikasi

## 📊 Ringkasan Umum
Role **"booking"** adalah role khusus yang diberikan kepada pengguna yang hanya boleh melakukan pemesanan ruangan. Role ini memiliki akses terbatas dan hanya dapat mengakses fitur pemesanan.

---

## 🔍 Detail Penggunaan Booking Role

### 1. **Model Definition** 
**File:** [`lib/models/user_model.dart`](lib/models/user_model.dart)

```dart
enum UserRole { user, admin, booking }
```

**Fungsi:**
- Mendefinisikan 3 role utama: `user`, `admin`, dan `booking`
- `booking` adalah enum case khusus untuk pengguna yang hanya bisa booking

**Penggunaan dalam conversion:**
```dart
// From JSON (Firebase)
role: json['role'] == 'booking' ? UserRole.booking : UserRole.user

// To JSON (ke Firebase)
'role': role == UserRole.booking ? 'booking' : 'user'
```

---

### 2. **Authentication Provider**
**File:** [`lib/providers/auth_provider.dart`](lib/providers/auth_provider.dart)

```dart
// Line 214-215
: roleString == 'booking'
? UserRole.booking
```

**Fungsi:**
- Mengonversi string role dari Firebase ke enum `UserRole.booking`
- Dijalankan saat user login atau data user dimuat dari Firebase

---

### 3. **Home Screen Navigation**
**File:** [`lib/screens/home/home_screen.dart`](lib/screens/home/home_screen.dart)

```dart
// Line 118
if (authProvider.userModel?.role == UserRole.booking) {
  return const RoomsListScreen();
}
```

**Fungsi:**
- **Redirect khusus untuk Booking role**
- User dengan role `booking` langsung ditampilkan `RoomsListScreen` (daftar ruangan)
- User lain (user, admin) ditampilkan dashboard biasa dengan bottom navigation

**Flow:**
```
Login dengan role booking
       ↓
Home Screen diload
       ↓
Cek: apakah role == UserRole.booking?
       ↓
Ya → Tampilkan RoomsListScreen (hanya list ruangan)
Tidak → Tampilkan Dashboard (home, booking history, profile)
```

---

### 4. **Room Details Screen - Access Control**
**File:** [`lib/screens/room/room_details_screen.dart`](lib/screens/room/room_details_screen.dart)

```dart
// Line 115
if (authProvider.user == null || authProvider.userModel?.role != UserRole.booking) {
  // Tampilkan Access Denied screen
}
```

**Fungsi:**
- **Proteksi akses halaman detail ruangan**
- Hanya user dengan role `booking` yang bisa:
  - Melihat detail ruangan
  - Akses halaman booking form
  
**Error Message:**
```
"Access Denied"
"This interface is exclusive for Bookings role only"
```

---

### 5. **Booking Form Screen - Access Control**
**File:** [`lib/screens/booking/booking_form_screen.dart`](lib/screens/booking/booking_form_screen.dart)

```dart
// Line 523
if (authProvider.user == null || authProvider.userModel?.role != UserRole.booking) {
  // Tampilkan Access Denied screen
}
```

**Fungsi:**
- **Proteksi akses form pemesanan**
- Hanya user dengan role `booking` yang bisa membuat booking

**Error Message:**
```
"Access Denied"
"Only users with Bookings role can access this page"
```

---

### 6. **Sign Up Screen - Role Selection**
**File:** [`lib/screens/auth/signup_screen.dart`](lib/screens/auth/signup_screen.dart)

```dart
// Line 322
if (_selectedRole == 'booking')
  // Set role ke booking saat registrasi
```

**Fungsi:**
- User dapat memilih role `booking` saat sign up
- Role disimpan ke Firebase dengan string `'booking'`

---

## 📋 Tabel Ringkasan Penggunaan

| Lokasi | Fungsi | Aksi |
|--------|--------|------|
| **user_model.dart** | Definisi enum & conversion | Parsing dari/ke JSON Firebase |
| **auth_provider.dart** | Login/Load user | Convert string 'booking' → UserRole.booking |
| **home_screen.dart** | Navigation routing | IF role==booking → RoomsListScreen |
| **room_details_screen.dart** | Akses detail ruangan | BLOCK jika role ≠ booking |
| **booking_form_screen.dart** | Akses form booking | BLOCK jika role ≠ booking |
| **signup_screen.dart** | Registrasi user | Pilih role 'booking' saat signup |

---

## 🔐 Access Control Summary

### User dengan Role "booking" bisa:
✅ Melihat daftar ruangan (`RoomsListScreen`)  
✅ Melihat detail ruangan tertentu  
✅ Akses form pemesanan ruangan  
✅ Membuat booking baru  
✅ Melihat profil sendiri  

### User dengan Role "booking" TIDAK bisa:
❌ Akses dashboard Home (Tab: Home, Booking History, Profile)  
❌ Mengakses fitur admin  
❌ Fitur lain dari user biasa  

---

## 🎯 Workflow Lengkap User Booking

```
1. User Sign Up
   └─ Pilih role: "booking"
      └─ Save ke Firebase dengan role='booking'

2. User Login
   └─ AuthProvider load user dari Firebase
      └─ Convert role string 'booking' → UserRole.booking
         └─ Save ke authProvider.userModel.role

3. Masuk Home Screen
   └─ Check: role == UserRole.booking?
      └─ YES → Show RoomsListScreen
              └─ User hanya bisa lihat daftar ruangan
                 └─ Click ruangan → RoomDetailsScreen
                    └─ Check: role == UserRole.booking?
                       └─ YES → Show room details + booking form
                       └─ NO  → Access Denied

4. Booking Process
   └─ BookingFormScreen
      └─ Check: role == UserRole.booking?
         └─ YES → Show form & allow booking
         └─ NO  → Access Denied
```

---

## 📝 Firebase Data Structure

```json
// User document dengan role "booking"
{
  "id": "user123",
  "name": "John Doe",
  "email": "john@example.com",
  "role": "booking",          // ← String 'booking' di Firebase
  "createdAt": 1704547200000,
  "updatedAt": 1704633600000
}
```

---

## 💡 Key Points

1. **Exclusive Role**: Role `booking` adalah role khusus dengan akses sangat terbatas
2. **Access Control**: Implementasi 2-layer protection di RoomDetailsScreen dan BookingFormScreen
3. **Navigation Flow**: Home screen mengalihkan role booking langsung ke RoomsListScreen
4. **String Conversion**: Penting konversi string 'booking' ↔ enum UserRole.booking
5. **Security**: Role check dilakukan di frontend (UI protection) dan backend (Firebase rules)

---

## 🔗 Related Files
- [`lib/models/user_model.dart`](lib/models/user_model.dart) - Model definition
- [`lib/providers/auth_provider.dart`](lib/providers/auth_provider.dart) - Authentication logic
- [`lib/screens/home/home_screen.dart`](lib/screens/home/home_screen.dart) - Navigation routing
- [`lib/screens/room/room_details_screen.dart`](lib/screens/room/room_details_screen.dart) - Room access control
- [`lib/screens/booking/booking_form_screen.dart`](lib/screens/booking/booking_form_screen.dart) - Booking access control
- [`lib/screens/auth/signup_screen.dart`](lib/screens/auth/signup_screen.dart) - Role selection
