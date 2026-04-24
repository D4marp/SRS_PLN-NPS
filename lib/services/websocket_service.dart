import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/room_model.dart';
import '../models/booking_model.dart';
import '../utils/api_config.dart';

/// WebSocket service replacing Firebase Firestore real-time streams.
///
/// Endpoints:
///   WS /ws/rooms           — rooms list (no auth required)
///   WS /ws/bookings?token= — bookings list (JWT in query param)
class WebSocketService {
  static String get _wsBase {
    // Replace http(s):// with ws(s)://
    return ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
  }

  // ─── Rooms ─────────────────────────────────────────────────────────────────

  /// Returns a broadcast stream that emits a fresh list of [RoomModel]
  /// on initial connect and on every server-side broadcast.
  static Stream<List<RoomModel>> watchRooms({String? city}) {
    final query = city != null && city.isNotEmpty ? '?city=$city' : '';
    final uri = Uri.parse('$_wsBase/ws/rooms$query');

    final controller = StreamController<List<RoomModel>>.broadcast();
    WebSocketChannel? channel;
    bool disposed = false;

    void connect() {
      if (disposed) return;
      try {
        channel = WebSocketChannel.connect(uri);
        channel!.stream.listen(
          (data) {
            try {
              final msg = jsonDecode(data as String) as Map<String, dynamic>;
              final type = msg['type'] as String?;
              if (type == 'initial' || type == 'update') {
                final rawList = msg['data'] as List<dynamic>;
                final rooms = rawList
                    .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();
                if (!controller.isClosed) controller.add(rooms);
              }
            } catch (e) {
              debugPrint('WebSocket rooms parse error: $e');
            }
          },
          onError: (error) {
            debugPrint('WebSocket rooms error: $error — reconnecting in 5s');
            Future.delayed(const Duration(seconds: 5), connect);
          },
          onDone: () {
            debugPrint('WebSocket rooms closed — reconnecting in 5s');
            if (!disposed) Future.delayed(const Duration(seconds: 5), connect);
          },
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint('WebSocket rooms connect failed: $e');
        Future.delayed(const Duration(seconds: 5), connect);
      }
    }

    controller.onListen = connect;
    controller.onCancel = () {
      disposed = true;
      channel?.sink.close();
    };

    return controller.stream;
  }

  // ─── Bookings ──────────────────────────────────────────────────────────────

  /// Returns a broadcast stream that emits a fresh list of [BookingModel].
  /// Requires a valid JWT token (from [ApiConfig.token]).
  static Stream<List<BookingModel>> watchBookings({String? token}) {
    final jwt = token ?? ApiConfig.token ?? '';
    if (jwt.isEmpty) {
      debugPrint('WebSocket bookings: no token, stream will be empty');
      return const Stream.empty();
    }

    final uri = Uri.parse('$_wsBase/ws/bookings?token=${Uri.encodeComponent(jwt)}');
    final controller = StreamController<List<BookingModel>>.broadcast();
    WebSocketChannel? channel;
    bool disposed = false;

    void connect() {
      if (disposed) return;
      try {
        channel = WebSocketChannel.connect(uri);
        channel!.stream.listen(
          (data) {
            try {
              final msg = jsonDecode(data as String) as Map<String, dynamic>;
              final type = msg['type'] as String?;
              if (type == 'initial' || type == 'update') {
                final rawList = msg['data'] as List<dynamic>;
                final bookings = rawList
                    .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();
                if (!controller.isClosed) controller.add(bookings);
              }
            } catch (e) {
              debugPrint('WebSocket bookings parse error: $e');
            }
          },
          onError: (error) {
            debugPrint('WebSocket bookings error: $error — reconnecting in 5s');
            Future.delayed(const Duration(seconds: 5), connect);
          },
          onDone: () {
            debugPrint('WebSocket bookings closed — reconnecting in 5s');
            if (!disposed) Future.delayed(const Duration(seconds: 5), connect);
          },
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint('WebSocket bookings connect failed: $e');
        Future.delayed(const Duration(seconds: 5), connect);
      }
    }

    controller.onListen = connect;
    controller.onCancel = () {
      disposed = true;
      channel?.sink.close();
    };

    return controller.stream;
  }
}
