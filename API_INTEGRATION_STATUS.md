# 🔴 API Integration Status - TIDAK SESUAI

## ⚠️ MASALAH UTAMA

### Current State (Flutter App)
```
✅ Authentication: Firebase Auth (Email/Password)
✅ Database: Cloud Firestore
✅ Storage: Firebase Storage
✅ Real-time: Firestore Listeners
```

### Backend yang Sudah Dibuat
```
✅ Authentication: JWT Token + MySQL
✅ Database: MySQL (bookify_rooms)
✅ Storage: Local/Database
✅ Real-time: Socket.io
```

## 🚨 PERBEDAAN MENDASAR

| Aspek | Flutter App | Backend API |
|-------|------------|------------|
| **Auth Method** | Firebase Auth | JWT Token |
| **Database** | Cloud Firestore | MySQL |
| **Data Storage** | Firestore Collections | MySQL Tables |
| **Real-time** | Firestore Listeners | Socket.io |
| **User Management** | Firebase UID | UUID/Email |
| **API Call** | Firestore SDK | REST API |

---

## 📋 ANALISIS DETAIL

### 1. Authentication ❌ TIDAK SESUAI
**Flutter App (Current):**
```dart
// lib/services/auth_service.dart
static Future<UserCredential?> signInWithEmail({
  required String email,
  required String password,
}) async {
  UserCredential credential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  return credential;
}
```
- Menggunakan Firebase Auth SDK
- User data disimpan di Firebase UID
- Tidak ada JWT token generation

**Backend API (Actual):**
```javascript
// src/routes/auth.js
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  // Validate credentials
  const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
    expiresIn: '7d'
  });
  return token; // Returns JWT, not Firebase credential
});
```
- Menggunakan custom JWT tokens
- User data disimpan di MySQL
- Memerlukan HTTP request untuk login

---

### 2. Database & Data Access ❌ TIDAK SESUAI
**Flutter App (Current):**
```dart
// lib/services/room_service.dart
static Stream<List<RoomModel>> getAllRooms() {
  return _firestore
      .collection('rooms')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => RoomModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });
}
```
- Direct Firestore collection queries
- Real-time stream listeners
- NoSQL document structure

**Backend API (Actual):**
```javascript
// src/routes/rooms.js
router.get('/rooms', async (req, res) => {
  const [rooms] = await pool.query(
    'SELECT * FROM rooms WHERE is_available = true'
  );
  res.json(rooms);
});
```
- REST API endpoints
- HTTP requests (no real-time)
- SQL relational structure

---

### 3. Bookings System ❌ TIDAK SESUAI
**Flutter App (Current):**
```dart
// lib/services/booking_service.dart
await _firestore
    .collection('bookings')
    .doc(bookingId)
    .set(booking.toJson());
```
- Direct Firestore writes
- Firestore security rules for validation
- Real-time sync via listeners

**Backend API (Actual):**
```javascript
// src/routes/bookings.js
router.post('/bookings', authenticateToken, async (req, res) => {
  const { roomId, bookingDate, checkInTime, checkOutTime } = req.body;
  // Validate availability
  const [result] = await pool.query(
    'INSERT INTO bookings (user_id, room_id, booking_date, check_in_time, check_out_time) VALUES (?, ?, ?, ?, ?)',
    [userId, roomId, bookingDate, checkInTime, checkOutTime]
  );
});
```
- POST requests dengan JWT auth header
- Server-side validation
- Manual time slot checking

---

### 4. Real-time Updates ❌ TIDAK SESUAI
**Flutter App (Current):**
```dart
// Real-time listeners
_firestore.collection('bookings').snapshots().listen(...)
```
- Firestore real-time listeners
- Automatic sync across devices

**Backend API (Actual):**
```javascript
// server.js
const io = require('socket.io')(server, {
  cors: { origin: 'http://localhost:5000' }
});
```
- Socket.io for real-time
- Manual event emission
- Requires Socket.io client library

---

## 🔧 SOLUSI

### OPSI 1: Update Flutter App ke REST API (Rekomendasi ⭐)
**Keuntungan:**
- Backend sudah siap 100%
- Lebih sederhana (hanya perlu HTTP requests)
- Hemat biaya (MySQL lokal vs Firebase)
- Full control atas backend

**Kebutuhan:**
1. Buat API Service dengan Dio
2. Update AuthProvider untuk JWT
3. Update RoomProvider untuk REST API
4. Update BookingProvider untuk REST API
5. Integrasikan Socket.io untuk real-time
6. Ganti Firestore dependencies

**Estimated Time:** 4-6 jam

---

### OPSI 2: Buat Firebase Backend (Alternative)
**Keuntungan:**
- Cocok dengan Flutter app yang sudah ada
- Minimal code changes
- Real-time built-in

**Kekurangan:**
- Perlu buat ulang backend dengan Firebase Functions
- Lebih mahal (Firebase billing)
- Backend Node.js jadi tidak terpakai

**Estimated Time:** 8-10 jam

---

## 📊 PERBANDINGAN OPSI

| Aspek | Opsi 1: REST API | Opsi 2: Firebase |
|-------|-----------------|-----------------|
| **Waktu Setup** | 4-6 jam | 8-10 jam |
| **Backend Baru** | Tidak (gunakan existing) | Ya |
| **Cost** | Murah (MySQL lokal) | Mahal (Firebase) |
| **Real-time** | Socket.io | Built-in |
| **Complexity** | Medium | Low |
| **Scalability** | Bagus | Excellent |
| **Backend Code** | Gunakan semua | Buang semua |

---

## ✅ REKOMENDASI: OPSI 1 (REST API)

Karena backend sudah fully implemented dengan MySQL, API endpoints ready, dan semua business logic sudah ada, lebih efisien **update Flutter app untuk consume REST API**.

### Langkah-langkah Implementasi:

#### 1. Setup API Service (Dio HTTP Client)
```dart
// lib/services/api_service.dart
class ApiService {
  static const String _baseUrl = 'http://localhost:5002/api';
  static final Dio _dio = Dio();
  static String? _token;

  static void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/auth/login',
      data: { 'email': email, 'password': password },
    );
    return response.data;
  }

  // Get all rooms
  static Future<List<dynamic>> getAllRooms() async {
    final response = await _dio.get('$_baseUrl/rooms');
    return response.data;
  }

  // Create booking
  static Future<Map<String, dynamic>> createBooking({
    required String roomId,
    required String bookingDate,
    required String checkInTime,
    required String checkOutTime,
    required int numberOfGuests,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/bookings',
      data: {
        'room_id': roomId,
        'booking_date': bookingDate,
        'check_in_time': checkInTime,
        'check_out_time': checkOutTime,
        'number_of_guests': numberOfGuests,
      },
    );
    return response.data;
  }
}
```

#### 2. Update Authentication
```dart
// lib/services/auth_service.dart (Replace Firebase with API)
class AuthService {
  static Future<String?> login(String email, String password) async {
    final response = await ApiService.login(email: email, password: password);
    final token = response['token'];
    ApiService.setToken(token);
    return token;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _dio.post(
      '$_baseUrl/auth/register',
      data: { 'name': name, 'email': email, 'password': password },
    );
  }
}
```

#### 3. Update Room Provider
```dart
// lib/providers/room_provider.dart
class RoomProvider extends ChangeNotifier {
  List<RoomModel> _rooms = [];
  bool _isLoading = false;

  Future<void> fetchRooms() async {
    _isLoading = true;
    try {
      final data = await ApiService.getAllRooms();
      _rooms = (data as List)
          .map((room) => RoomModel.fromJson(room))
          .toList();
    } catch (e) {
      print('Error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }
}
```

#### 4. Update Booking Provider
```dart
// lib/providers/booking_provider.dart
class BookingProvider extends ChangeNotifier {
  Future<bool> createBooking({
    required String roomId,
    required DateTime bookingDate,
    required String checkInTime,
    required String checkOutTime,
    required int numberOfGuests,
  }) async {
    try {
      await ApiService.createBooking(
        roomId: roomId,
        bookingDate: bookingDate.toString(),
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        numberOfGuests: numberOfGuests,
      );
      return true;
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }
}
```

---

## 🎯 NEXT STEPS

### Immediate (Hari Ini)
- [ ] Tentukan pilihan: Opsi 1 (REST API) atau Opsi 2 (Firebase)
- [ ] Jika Opsi 1: Update `pubspec.yaml` dengan Dio dependency
- [ ] Buat `lib/services/api_service.dart`

### Short Term (Minggu Ini)
- [ ] Update authentication services
- [ ] Update room services
- [ ] Update booking services
- [ ] Test semua endpoints

### Medium Term (Minggu Depan)
- [ ] Integrasikan Socket.io untuk real-time
- [ ] Full testing & debugging
- [ ] Deploy ke production

---

## 📝 SUMMARY

**Status:** ❌ **TIDAK SESUAI** (Masalah fundamental antara Firestore vs MySQL)

**Root Cause:** 
- Flutter app dibangun untuk Firebase/Firestore
- Backend API dibangun untuk MySQL REST API
- Kedua teknologi berbeda signifikan

**Solusi:** 
- Pilih 1 stack: Firestore (OPSI 2) atau MySQL+REST (OPSI 1)
- **Rekomendasi:** OPSI 1 (karena backend sudah ready)

**Effort:** 4-6 jam untuk update Flutter app

**Priority:** 🔴 HIGH - Harus diselesaikan sebelum testing

---

**Lanjutkan dengan OPSI 1 atau OPSI 2? Keputusan Anda!**
