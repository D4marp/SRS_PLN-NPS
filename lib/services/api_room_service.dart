import 'dart:io';
import 'package:dio/dio.dart';
import '../models/room_model.dart';
import '../utils/api_config.dart';

/// HTTP service for all /api/rooms/* endpoints on the Go backend.
/// Replaces Firebase Firestore for room CRUD operations and
/// Firebase Storage for image uploads.
class ApiRoomService {
  static Dio _dio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    if (ApiConfig.token != null) {
      dio.options.headers['Authorization'] = 'Bearer ${ApiConfig.token}';
    }
    return dio;
  }

  // ─── Read (public) ──────────────────────────────────────────────────────────

  /// Fetch rooms list with optional filters (no auth required).
  static Future<List<RoomModel>> listRooms({
    String? city,
    String? roomClass,
    bool? hasAC,
    int? minGuests,
    String? search,
    bool? available,
  }) async {
    final resp = await _dio().get('/api/rooms', queryParameters: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (roomClass != null && roomClass.isNotEmpty) 'roomClass': roomClass,
      if (hasAC != null) 'hasAC': hasAC,
      if (minGuests != null) 'minGuests': minGuests,
      if (search != null && search.isNotEmpty) 'search': search,
      if (available != null) 'available': available,
    });
    final list = resp.data['data'] as List<dynamic>;
    return list
        .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Get a single room by ID (no auth required).
  static Future<RoomModel> getRoom(String id) async {
    final resp = await _dio().get('/api/rooms/$id');
    return RoomModel.fromJson(
        Map<String, dynamic>.from(resp.data['data'] as Map));
  }

  // ─── Write (admin) ──────────────────────────────────────────────────────────

  /// Create a new room (admin/superadmin). Returns the created room.
  static Future<RoomModel> createRoom({
    required String name,
    required String description,
    required String location,
    required String city,
    required String roomClass,
    required int maxGuests,
    required String contactNumber,
    List<String> amenities = const [],
    bool hasAC = false,
    bool isAvailable = true,
    String? floor,
    String? building,
  }) async {
    final resp = await _dio().post('/api/rooms', data: {
      'name': name,
      'description': description,
      'location': location,
      'city': city,
      'roomClass': roomClass,
      'maxGuests': maxGuests,
      'contactNumber': contactNumber,
      'amenities': amenities,
      'hasAC': hasAC,
      'isAvailable': isAvailable,
      if (floor != null && floor.isNotEmpty) 'floor': floor,
      if (building != null && building.isNotEmpty) 'building': building,
    });
    return RoomModel.fromJson(
        Map<String, dynamic>.from(resp.data['data'] as Map));
  }

  /// Update an existing room (admin/superadmin). Returns the updated room.
  static Future<RoomModel> updateRoom(String id, {
    String? name,
    String? description,
    String? location,
    String? city,
    String? roomClass,
    int? maxGuests,
    String? contactNumber,
    List<String>? amenities,
    bool? hasAC,
    bool? isAvailable,
    String? floor,
    String? building,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (location != null) body['location'] = location;
    if (city != null) body['city'] = city;
    if (roomClass != null) body['roomClass'] = roomClass;
    if (maxGuests != null) body['maxGuests'] = maxGuests;
    if (contactNumber != null) body['contactNumber'] = contactNumber;
    if (amenities != null) body['amenities'] = amenities;
    if (hasAC != null) body['hasAC'] = hasAC;
    if (isAvailable != null) body['isAvailable'] = isAvailable;
    if (floor != null) body['floor'] = floor.isNotEmpty ? floor : null;
    if (building != null) body['building'] = building.isNotEmpty ? building : null;

    final resp = await _dio().put('/api/rooms/$id', data: body);
    return RoomModel.fromJson(
        Map<String, dynamic>.from(resp.data['data'] as Map));
  }

  /// Delete a room (admin/superadmin).
  static Future<void> deleteRoom(String id) async {
    await _dio().delete('/api/rooms/$id');
  }

  // ─── Image management ───────────────────────────────────────────────────────

  /// Upload an image file for a room. Returns the public URL.
  static Future<String> uploadImage(String roomId, File imageFile) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });
    final resp = await _dio().post(
      '/api/rooms/$roomId/images',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return resp.data['data']['imageUrl'] as String;
  }

  /// Remove an image URL from a room and delete the physical file.
  static Future<void> deleteImage(String roomId, String imageUrl) async {
    await _dio().delete(
      '/api/rooms/$roomId/images',
      data: {'imageUrl': imageUrl},
    );
  }
}
