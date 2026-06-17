import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/user_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../core/gen/assets.gen.dart';
import '../booking/booking_form_screen.dart';
import '../../services/api_booking_service.dart';
import '../../widgets/feedback_modal.dart';

// Event-driven data class untuk booking updates
class BookingUpdateEvent {
  final List<BookingModel> bookings;
  final DateTime timestamp;

  BookingUpdateEvent({
    required this.bookings,
    required this.timestamp,
  });
}

class RoomDetailsScreen extends StatefulWidget {
  final RoomModel room;
  final bool isKioskMode;

  const RoomDetailsScreen({
    super.key,
    required this.room,
    this.isKioskMode = false,
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  static const Duration _checkoutGracePeriod = Duration(minutes: 30);

  late Timer _timeUpdateTimer;
  late ValueNotifier<DateTime> _timeNotifier;
  late StreamController<BookingUpdateEvent> _bookingEventController;

  // Cache untuk menghindari rebuild berlebihan
  List<BookingModel>? _cachedBookings;
  List<BookingModel>? _cachedTodayBookings;
  DateTime? _lastBookingUpdateTime;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    debugPrint('🚀 RoomDetailsScreen initState: Room ID = ${widget.room.id}');
    debugPrint(
        '🔥 Using API-FIRST architecture with WebSocket real-time updates!');

    // Initialize time notifier
    _timeNotifier = ValueNotifier<DateTime>(DateTime.now());

    // Initialize booking event controller
    _bookingEventController = StreamController<BookingUpdateEvent>.broadcast();

    // Update time every 1 second for smooth real-time clock display
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _timeNotifier.value = DateTime.now();
      }
    });
  }

  List<BookingModel> _filterBookingsForToday(List<BookingModel> bookings) {
    // Filter bookings untuk hari ini saja (realtime kios display)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return bookings.where((booking) {
      // Parse booking date to same-day comparison
      final bookingDay = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      return bookingDay.isAtSameMomentAs(today);
    }).toList();
  }

  // Helper untuk check apakah data booking berubah
  bool _hasBookingsChanged(List<BookingModel> newBookings) {
    if (_cachedBookings == null ||
        newBookings.length != _cachedBookings!.length) {
      return true;
    }

    // Check setiap booking untuk perubahan
    for (int i = 0; i < newBookings.length; i++) {
      if (newBookings[i].id != _cachedBookings![i].id ||
          newBookings[i].status != _cachedBookings![i].status ||
          newBookings[i].checkInTime != _cachedBookings![i].checkInTime ||
          newBookings[i].checkOutTime != _cachedBookings![i].checkOutTime ||
          newBookings[i].actualCheckInTime !=
              _cachedBookings![i].actualCheckInTime ||
          newBookings[i].actualCheckOutTime !=
              _cachedBookings![i].actualCheckOutTime ||
          newBookings[i].hasFeedback != _cachedBookings![i].hasFeedback) {
        return true;
      }
    }

    return false;
  }

  @override
  void dispose() {
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _timeUpdateTimer.cancel();
    _timeNotifier.dispose();
    _bookingEventController.close();
    super.dispose();
  }

  String _getCurrentTimeString(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getBookingStatusText(BookingModel booking, DateTime currentTime) {
    final bookingStart = _parseTimeOnDate(
      booking.bookingDate,
      booking.checkInTime,
    );
    final bookingEnd = _parseTimeOnDate(
      booking.bookingDate,
      booking.checkOutTime,
    );
    final actualStart = _parseTimeOnDate(
      booking.bookingDate,
      booking.actualCheckInTime,
    );
    final actualEnd = _parseTimeOnDate(
      booking.bookingDate,
      booking.actualCheckOutTime,
    );

    if (bookingStart == null || bookingEnd == null) {
      return 'Invalid Time';
    }

    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        actualEnd != null) {
      return 'Completed';
    }

    final checkoutGraceEnd = bookingEnd.add(_checkoutGracePeriod);

    if (actualStart != null) {
      if (currentTime.isAfter(actualStart) ||
          currentTime.isAtSameMomentAs(actualStart)) {
        if (_isAtOrAfter(currentTime, checkoutGraceEnd)) {
          return 'Completed';
        }
        return currentTime.isAfter(bookingEnd)
            ? 'Awaiting Check-out'
            : 'Ongoing';
      }
      if (currentTime.isBefore(actualStart)) {
        return 'Upcoming';
      }
    }

    if (currentTime.isBefore(bookingStart)) {
      return 'Upcoming';
    }
    if (_isAtOrAfter(currentTime, checkoutGraceEnd)) {
      return 'Completed';
    }
    if (currentTime.isAfter(bookingEnd)) {
      return 'Awaiting Check-out';
    }
    return 'Ongoing';
  }

  bool _isAtOrAfter(DateTime value, DateTime compareTo) {
    return value.isAfter(compareTo) || value.isAtSameMomentAs(compareTo);
  }

  bool _isActiveScheduleStatus(String statusText) {
    return statusText == 'Ongoing' ||
        statusText == 'Awaiting Check-out' ||
        statusText == 'Upcoming';
  }

  bool _shouldShowBookingInSchedule(
    BookingModel booking,
    DateTime currentTime,
  ) {
    if (booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        booking.status == BookingStatus.completed ||
        booking.actualCheckOutTime?.isNotEmpty == true) {
      return false;
    }

    return _isActiveScheduleStatus(
      _getBookingStatusText(booking, currentTime),
    );
  }

  bool _isOngoingForRoomStatus(
    BookingModel booking,
    DateTime currentTime,
  ) {
    final statusText = _getBookingStatusText(booking, currentTime);
    return _shouldShowBookingInSchedule(booking, currentTime) &&
        (statusText == 'Ongoing' || statusText == 'Awaiting Check-out');
  }

  int _schedulePriority(String statusText) {
    switch (statusText) {
      case 'Ongoing':
        return 0;
      case 'Awaiting Check-out':
        return 1;
      case 'Upcoming':
        return 2;
      default:
        return 3;
    }
  }

  String _formatTimeForDisplay(String? time) {
    if (time == null || time.isEmpty) {
      return '';
    }
    return time.replaceAll(':', '.');
  }

  String _getFormattedDate(DateTime time) {
    final days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${days[time.weekday - 1]}, ${time.day} ${months[time.month - 1]} ${time.year}';
  }

  String _getFormattedDateAndTime(
      DateTime date, String? checkInTime, String? checkOutTime) {
    final dateStr = _getFormattedDate(date);
    final timeStart = checkInTime?.replaceAll(':', '.') ?? '';
    final timeEnd = checkOutTime?.replaceAll(':', '.') ?? '';
    return '$dateStr $timeStart - $timeEnd';
  }

  String? _formatPihakLine(BookingModel booking) {
    final pihak1 = booking.pihak1?.trim();
    final pihak2 = booking.pihak2?.trim();

    if ((pihak1 == null || pihak1.isEmpty) &&
        (pihak2 == null || pihak2.isEmpty)) {
      return null;
    }
    if (pihak1 == null || pihak1.isEmpty) {
      return 'Pihak 2: $pihak2';
    }
    if (pihak2 == null || pihak2.isEmpty) {
      return 'Pihak 1: $pihak1';
    }
    return '$pihak1 dengan $pihak2';
  }

  DateTime? _parseTimeOnDate(DateTime date, String? time) {
    if (time == null || time.isEmpty) {
      return null;
    }
    final parts = time.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _getOngoingMeetingTime(List<BookingModel> bookings, DateTime now) {
    final todayBookings = _filterBookingsForToday(bookings);

    for (final booking in todayBookings) {
      final bookingStart = _parseTimeOnDate(
        booking.bookingDate,
        booking.checkInTime,
      );
      final bookingEnd = _parseTimeOnDate(
        booking.bookingDate,
        booking.checkOutTime,
      );
      final actualEnd = _parseTimeOnDate(
        booking.bookingDate,
        booking.actualCheckOutTime,
      );

      if (booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.rejected ||
          actualEnd != null ||
          bookingStart == null ||
          bookingEnd == null) {
        continue;
      }

      final isAfterStart =
          now.isAfter(bookingStart) || now.isAtSameMomentAs(bookingStart);
      final isBeforeEnd =
          now.isBefore(bookingEnd) || now.isAtSameMomentAs(bookingEnd);
      final isOngoing = isAfterStart && isBeforeEnd;

      if (isOngoing) {
        final displayStart = booking.checkInTime;
        final displayEnd = booking.checkOutTime;
        return '$displayStart - $displayEnd';
      }
    }

    return 'Tidak ada rapat berjalan';
  }

  // Event-driven method: dipanggil hanya saat booking data berubah
  void _onBookingDataChanged(List<BookingModel> bookings) {
    _lastBookingUpdateTime = DateTime.now();
    _bookingEventController.add(BookingUpdateEvent(
      bookings: bookings,
      timestamp: _lastBookingUpdateTime!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Check if user has Bookings role - ONLY Bookings role allowed
        if (authProvider.userModel == null ||
            authProvider.userModel?.role != UserRole.booking) {
          return Scaffold(
            body: Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Access Denied',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                                fontSize: 28,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This interface is exclusive for\nBookings role only',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          const Text('Go Back', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return WillPopScope(
          onWillPop: () async {
            // Prevent back navigation in kiosk mode
            if (widget.isKioskMode) {
              return false;
            }
            return true;
          },
          child: Scaffold(
            body: Stack(
              children: [
                // PLN Background Image
                Positioned.fill(
                  child: Assets.images.bgPLN.image(
                    fit: BoxFit.cover,
                  ),
                ),

                // Main Content
                SafeArea(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.033),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side - Room Info
          SizedBox(
            width: screenWidth * 0.35,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Assets.images.logoPLN.image(
                      width: screenWidth * 0.18,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.018),
                  // Room Image
                  Container(
                    height: screenHeight * 0.35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.room.imageUrls.isNotEmpty
                        ? Image.network(
                            widget.room.imageUrls.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withOpacity(0.1),
                                child: Center(
                                  child: Icon(
                                    Icons.meeting_room,
                                    size: screenWidth * 0.06,
                                    color: AppColors.secondaryText
                                        .withOpacity(0.7),
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.white.withOpacity(0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.white.withOpacity(0.1),
                            child: Center(
                              child: Icon(
                                Icons.meeting_room,
                                size: screenWidth * 0.06,
                                color: AppColors.secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  // Room Name
                  Text(
                    widget.room.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.03,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: screenWidth * 0.017,
                      ),
                      SizedBox(width: screenWidth * 0.006),
                      Expanded(
                        child: Text(
                          '${widget.room.location}, ${widget.room.city}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.0125,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  // Facility
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Capacity:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.0125,
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.012),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.015,
                      vertical: screenHeight * 0.015,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(108),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people,
                          size: screenWidth * 0.018,
                          color: Colors.black,
                        ),
                        SizedBox(width: screenWidth * 0.006),
                        Text(
                          '${widget.room.maxGuests} Guests',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: screenWidth * 0.0127,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  // Facility
                  Text(
                    'Facilities:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.0125,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.012),
                  _buildFacilitiesSection(screenWidth, screenHeight),
                ],
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.025),
          // Right Side - Schedule & Booking
          Expanded(
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.026),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColorDark, width: 2),
                borderRadius: BorderRadius.circular(42),
              ),
              child: Column(
                children: [
                  // Header with Time and Status
                  // Badge (OCCUPIED/AVAILABLE) sits in top-right corner via Stack
                  // so the title can use full width without collision.
                  StreamBuilder<List<BookingModel>>(
                    stream: context
                        .read<BookingProvider>()
                        .watchBookingsByRoomIdStream(widget.room.id),
                    builder: (context, snapshot) {
                      return ValueListenableBuilder<DateTime>(
                        valueListenable: _timeNotifier,
                        builder: (context, currentTime, _) {
                          BookingModel? ongoingBooking;

                          if (snapshot.hasData && snapshot.data != null) {
                            final todayBookings =
                                _filterBookingsForToday(snapshot.data ?? []);
                            for (final booking in todayBookings) {
                              if (_isOngoingForRoomStatus(
                                booking,
                                currentTime,
                              )) {
                                ongoingBooking = booking;
                                break;
                              }
                            }
                          }

                          final hasOngoingMeeting = ongoingBooking != null;

                          String availabilityHeader = '';
                          if (!hasOngoingMeeting &&
                              snapshot.hasData &&
                              snapshot.data != null) {
                            final todayBookings =
                                _filterBookingsForToday(snapshot.data!);
                            DateTime? nextStart;
                            for (var b in todayBookings) {
                              if (!_shouldShowBookingInSchedule(
                                b,
                                currentTime,
                              )) {
                                continue;
                              }
                              final start = _parseTimeOnDate(
                                  b.bookingDate, b.checkInTime);
                              if (start != null && start.isAfter(currentTime)) {
                                if (nextStart == null ||
                                    start.isBefore(nextStart)) {
                                  nextStart = start;
                                }
                              }
                            }
                            final now = currentTime;
                            final startStr =
                                '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
                            final endStr = nextStart != null
                                ? '${nextStart.hour.toString().padLeft(2, '0')}.${nextStart.minute.toString().padLeft(2, '0')}'
                                : '24.00';
                            availabilityHeader = '$startStr - $endStr';
                          }

                          final meetingTitle = hasOngoingMeeting
                              ? (ongoingBooking!.purpose?.isNotEmpty == true
                                  ? ongoingBooking!.purpose!
                                  : 'Rapat')
                              : (availabilityHeader.isNotEmpty
                                  ? availabilityHeader
                                  : '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}');
                          final meetingScheduleLine = hasOngoingMeeting
                              ? '${_getFormattedDate(ongoingBooking!.bookingDate)} ${_formatTimeForDisplay(ongoingBooking!.checkInTime)} - ${_formatTimeForDisplay(ongoingBooking!.checkOutTime)}'
                              : _getFormattedDate(currentTime);
                          final meetingPihakLine = hasOngoingMeeting
                              ? _formatPihakLine(ongoingBooking!)
                              : null;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: title + schedule info (takes remaining space)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meetingTitle,
                                      style: TextStyle(
                                        color: const Color(0xFFEFE62F),
                                        fontSize: screenWidth * 0.022,
                                        fontFamily: 'Arial',
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                      // No maxLines limit — let it wrap naturally
                                      softWrap: true,
                                    ),
                                    SizedBox(height: screenHeight * 0.004),
                                    Text(
                                      meetingScheduleLine,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: screenWidth * 0.013,
                                        fontFamily: 'Arial',
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.003),
                                    if (meetingPihakLine != null &&
                                        meetingPihakLine.isNotEmpty) ...[
                                      Text(
                                        meetingPihakLine,
                                        style: TextStyle(
                                          color: const Color(0xFFEFE62F),
                                          fontSize: screenWidth * 0.012,
                                          fontFamily: 'Arial',
                                          fontWeight: FontWeight.w700,
                                        ),
                                        softWrap: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              // Right: badge — fixed width, aligned top
                              _buildAvailabilityStatus(
                                  screenWidth, screenHeight),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Divider(color: AppColors.borderColorDark, thickness: 2),
                  SizedBox(height: screenHeight * 0.02),
                  // Booked Schedule Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Booked Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.0125,
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Schedule List
                  Expanded(
                    child: _buildScheduleList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesSection(double screenWidth, double screenHeight) {
    final amenities =
        widget.room.amenities.where((item) => item.trim().isNotEmpty).toList();

    if (widget.room.hasAC &&
        !amenities.any((a) => a.toLowerCase().contains('ac'))) {
      amenities.insert(0, 'AC');
    }

    if (amenities.isEmpty) {
      return Text(
        'Belum ada fasilitas terdaftar',
        style: TextStyle(
          color: Colors.white70,
          fontSize: screenWidth * 0.0115,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(
      spacing: screenWidth * 0.01,
      runSpacing: screenHeight * 0.004,
      children: amenities.map((item) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.008,
            vertical: screenHeight * 0.003,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // On mobile app we render facilities without icon per request
              // (website will keep icons). Only show text here.
              Text(
                item,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.009,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForFacility(String value) {
    final key = value.toLowerCase();
    if (key.contains('ac') || key.contains('air')) return Icons.ac_unit;
    if (key.contains('projector') || key.contains('proyektor')) return Icons.tv;
    if (key.contains('whiteboard') || key.contains('board'))
      return Icons.border_color;
    if (key.contains('interactive') || key.contains('panel'))
      return Icons.touch_app;
    if (key.contains('video') || key.contains('conference'))
      return Icons.videocam;
    if (key.contains('speaker')) return Icons.volume_up;
    if (key.contains('wifi') || key.contains('internet')) return Icons.wifi;
    if (key.contains('hdmi')) return Icons.cable;
    if (key.contains('tv')) return Icons.tv;
    if (key.contains('pantry') || key.contains('coffee'))
      return Icons.local_cafe;
    return Icons.check_circle;
  }

  Widget _buildAvailabilityStatus(double screenWidth, double screenHeight) {
    return StreamBuilder<List<BookingModel>>(
      stream: context
          .read<BookingProvider>()
          .watchBookingsByRoomIdStream(widget.room.id),
      builder: (context, snapshot) {
        return ValueListenableBuilder<DateTime>(
          valueListenable: _timeNotifier,
          builder: (context, currentTime, _) {
            bool isAvailable = true;
            String? ongoingMeetingTitle;
            String? pihakLine;
            String? ongoingBookedForName;
            String? ongoingBookedForCompany;
            String? ongoingDateTimeStr;

            String availabilityRange = '';
            if (snapshot.hasData && snapshot.data != null) {
              // Filter bookings for today only
              final todayBookings = _filterBookingsForToday(snapshot.data!);

              // Check if there's any ongoing booking
              for (var booking in todayBookings) {
                try {
                  if (_isOngoingForRoomStatus(booking, currentTime)) {
                    isAvailable = false;
                    // Get meeting title from purpose field
                    ongoingMeetingTitle = booking.purpose ?? 'Meeting';
                    pihakLine = _formatPihakLine(booking);
                    ongoingBookedForName = booking.bookedForName;
                    ongoingBookedForCompany = booking.bookedForCompany;
                    ongoingDateTimeStr = _getFormattedDateAndTime(
                      booking.bookingDate,
                      booking.checkInTime,
                      booking.checkOutTime,
                    );
                    break;
                  }
                } catch (e) {
                  debugPrint('Error parsing booking time: $e');
                }
              }

              // If available, compute range until next booking start (today), otherwise until 24:00
              if (isAvailable) {
                DateTime? nextStart;
                for (var b in todayBookings) {
                  if (!_shouldShowBookingInSchedule(b, currentTime)) {
                    continue;
                  }
                  final start = _parseTimeOnDate(b.bookingDate, b.checkInTime);
                  if (start != null && start.isAfter(currentTime)) {
                    if (nextStart == null || start.isBefore(nextStart)) {
                      nextStart = start;
                    }
                  }
                }
                final now = currentTime;
                final startStr =
                    '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
                final endStr = nextStart != null
                    ? '${nextStart.hour.toString().padLeft(2, '0')}.${nextStart.minute.toString().padLeft(2, '0')}'
                    : '24.00';
                availabilityRange = '$startStr - $endStr';
              }
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.025,
                        vertical: screenHeight * 0.014,
                      ),
                      constraints: BoxConstraints(
                        minWidth: screenWidth * 0.12,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFF16BC00)
                            : const Color(0xFFB00000),
                        border: Border.all(
                          color: isAvailable
                              ? const Color(0xFF0D8A00)
                              : const Color(0xFF8B0000),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.event_busy,
                            color: Colors.white,
                            size: screenWidth * 0.018,
                          ),
                          SizedBox(width: screenWidth * 0.012),
                          Text(
                            isAvailable ? 'AVAILABLE' : 'OCCUPIED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isAvailable
                                  ? screenWidth * 0.0128
                                  : screenWidth * 0.0142,
                              fontFamily: 'Arial',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Meeting details only shown in yellow box on right
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bookingProvider = context.watch<BookingProvider>();

    return StreamBuilder<List<BookingModel>>(
      stream: bookingProvider.watchBookingsByRoomIdStream(widget.room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading schedule',
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth * 0.012,
              ),
            ),
          );
        }

        final allBookings = snapshot.data ?? [];

        // Update cache only if data actually changed
        if (_hasBookingsChanged(allBookings)) {
          _cachedBookings = allBookings;
          _cachedTodayBookings = _filterBookingsForToday(allBookings);
          _onBookingDataChanged(allBookings);
          debugPrint(
              '📊 Schedule updated: ${_cachedTodayBookings?.length ?? 0} bookings (API-first + WebSocket merge)');
        }

        final bookings = _cachedTodayBookings ?? [];

        // Wrap dengan ValueListenableBuilder untuk status updates tanpa rebuild data
        return ValueListenableBuilder<DateTime>(
          valueListenable: _timeNotifier,
          builder: (context, currentTime, _) {
            final visibleBookings = bookings
                .where(
                  (booking) => _shouldShowBookingInSchedule(
                    booking,
                    currentTime,
                  ),
                )
                .toList()
              ..sort((a, b) {
                final statusA = _getBookingStatusText(a, currentTime);
                final statusB = _getBookingStatusText(b, currentTime);
                final priorityCompare = _schedulePriority(statusA)
                    .compareTo(_schedulePriority(statusB));
                if (priorityCompare != 0) return priorityCompare;

                final startA = _parseTimeOnDate(a.bookingDate, a.checkInTime);
                final startB = _parseTimeOnDate(b.bookingDate, b.checkInTime);
                if (startA == null || startB == null) return 0;
                return startA.compareTo(startB);
              });

            return Stack(
              children: [
                // Bookings List
                visibleBookings.isEmpty
                    ? Center(
                        child: Text(
                          'No bookings for today',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.012,
                            fontFamily: 'Arial',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visibleBookings.length,
                        padding: EdgeInsets.only(bottom: screenHeight * 0.15),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final booking = visibleBookings[index];

                          // Determine booking status based on currentTime
                          Color borderColor;
                          Color statusBgColor;
                          Color statusTextColor;

                          final statusText =
                              _getBookingStatusText(booking, currentTime);

                          if (statusText == 'Invalid Time') {
                            borderColor = AppColors.secondaryText;
                            statusBgColor = AppColors.borderColorDark;
                            statusTextColor = AppColors.primaryText;
                          } else if (statusText == 'Ongoing') {
                            borderColor = const Color(0xFFFF0000);
                            statusBgColor = const Color(0xFFFF0000);
                            statusTextColor = Colors.white;
                          } else if (statusText == 'Awaiting Check-out') {
                            borderColor = AppColors.warningYellow;
                            statusBgColor = Colors.white.withOpacity(0.25);
                            statusTextColor = Colors.black;
                          } else {
                            borderColor = AppColors.secondaryText;
                            statusBgColor = AppColors.borderColorDark;
                            statusTextColor = AppColors.primaryText;
                          }

                          final isAwaitingCheckOut =
                              statusText == 'Awaiting Check-out';
                          final isOngoing = statusText == 'Ongoing';
                          final canCheckOut = isAwaitingCheckOut || isOngoing;

                          return Container(
                            margin:
                                EdgeInsets.only(bottom: screenHeight * 0.02),
                            padding: EdgeInsets.all(screenWidth * 0.012),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                // Left border indicator
                                Container(
                                  width: 3,
                                  height: screenHeight * 0.11,
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),

                                SizedBox(width: screenWidth * 0.012),

                                // Booking Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 1. Meeting purpose/title (Judul Meeting)
                                      if (booking.purpose != null &&
                                          booking.purpose!.isNotEmpty) ...[
                                        Text(
                                          booking.purpose!,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: screenWidth * 0.013,
                                            fontFamily: 'Arial',
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenHeight * 0.006),
                                      ],
                                      // 2. Date and Time range (Tanggal & Waktu)
                                      Text(
                                        _getFormattedDateAndTime(
                                          booking.bookingDate,
                                          booking.checkInTime,
                                          booking.checkOutTime,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: screenWidth * 0.012,
                                          fontFamily: 'Arial',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.008),
                                      // 3. Pihak section (NO background)
                                      if (_formatPihakLine(booking) !=
                                          null) ...[
                                        Text(
                                          _formatPihakLine(booking)!,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: screenWidth * 0.011,
                                            fontFamily: 'Arial',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenHeight * 0.004),
                                      ],
                                      // PIC: bookedForName · company
                                      if (booking.bookedForName != null &&
                                          booking.bookedForName!.isNotEmpty)
                                        Text(
                                          'PIC: ${booking.bookedForName}${booking.bookedForCompany != null && booking.bookedForCompany!.isNotEmpty ? ' · ${booking.bookedForCompany}' : ''}',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: screenWidth * 0.0105,
                                            fontFamily: 'Arial',
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),

                                // Status Badge or Check-In/Check-Out Button
                                if (canCheckOut)
                                  _CheckActionButton(
                                    booking: booking,
                                    bookingId: booking.id,
                                    isCheckIn: false,
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                  )
                                else
                                  Container(
                                    constraints: BoxConstraints(
                                      minWidth: screenWidth * 0.082,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.0062,
                                      vertical: screenHeight * 0.005,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusTextColor,
                                          fontSize: screenWidth * 0.011,
                                          fontFamily: 'Arial',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                // Add Booking Button (Bottom Right)
                // Temporarily hidden because booking is currently only available from admin.
                // Positioned(
                //   right: 0,
                //   bottom: 0,
                //   child: GestureDetector(
                //     onTap: () => _showBookingDialog(context),
                //     child: Center(
                //       child: Assets.icon.addBook.svg(
                //         width: screenWidth * 0.057,
                //         height: screenWidth * 0.057,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBookingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => BookingFormScreen(
          room: widget.room,
        ),
      ),
    );
  }
}

class _CheckActionButton extends StatefulWidget {
  final BookingModel booking;
  final String bookingId;
  final bool isCheckIn;
  final double screenWidth;
  final double screenHeight;

  const _CheckActionButton({
    required this.booking,
    required this.bookingId,
    required this.isCheckIn,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  State<_CheckActionButton> createState() => _CheckActionButtonState();
}

class _CheckActionButtonState extends State<_CheckActionButton> {
  bool _isLoading = false;
  bool _isDone = false;

  Future<void> _submitAction() async {
    if (_isLoading || _isDone) {
      return;
    }

    // Untuk CHECK-OUT: minta feedback DULU sebelum checkout
    if (!widget.isCheckIn && !widget.booking.hasFeedback) {
      // Tampilkan feedback modal terlebih dahulu
      final feedbackSubmitted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => FeedbackModal(
          booking: widget.booking,
          roomAmenities: widget.room.amenities,
          onFeedbackSubmitted: () {},
          autoSkipAfter: const Duration(minutes: 1),
        ),
      );

      // Jika user cancel feedback, jangan lanjut checkout
      if (feedbackSubmitted != true) {
        return;
      }
    }

    // Setelah feedback selesai (atau tidak perlu), lanjut submit action
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await ApiBookingService.submitCheckInCheckOut(
        bookingId: widget.bookingId,
        actualCheckInTime: widget.isCheckIn ? timeStr : null,
        actualCheckOutTime: widget.isCheckIn ? null : timeStr,
        markComplete: !widget.isCheckIn,
      );

      // Force refresh room bookings for real-time update after check-in/check-out
      if (mounted) {
        try {
          await context
              .read<BookingProvider>()
              .forceRefreshRoomBookings(widget.booking.roomId);
        } catch (e) {
          debugPrint('Warning: Force refresh failed: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isCheckIn
                  ? 'Check-in berhasil pukul $timeStr'
                  : 'Check-out berhasil pukul $timeStr',
            ),
            backgroundColor: widget.isCheckIn
                ? const Color(0xFF16BC00)
                : AppColors.warningYellow,
          ),
        );
        setState(() => _isDone = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isCheckIn
                ? 'Check-in gagal: $e'
                : 'Check-out gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.screenWidth * 0.025,
        height: widget.screenWidth * 0.025,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryBlue),
        ),
      );
    }

    if (_isDone) {
      return Container(
        constraints: BoxConstraints(
          minWidth: widget.screenWidth * 0.082,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.screenWidth * 0.0062,
          vertical: widget.screenHeight * 0.005,
        ),
        decoration: BoxDecoration(
          color: widget.isCheckIn
              ? const Color(0xFF16BC00)
              : AppColors.warningYellow,
          borderRadius: BorderRadius.circular(37),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check,
                color: Colors.white,
                size: widget.screenWidth * 0.013,
              ),
              SizedBox(width: widget.screenWidth * 0.004),
              Text(
                widget.isCheckIn ? 'Checked In' : 'Checked Out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.screenWidth * 0.011,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _submitAction,
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.screenWidth * 0.082,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.screenWidth * 0.0062,
          vertical: widget.screenHeight * 0.005,
        ),
        decoration: BoxDecoration(
          color: widget.isCheckIn
              ? AppColors.secondaryBlue
              : AppColors.warningYellow,
          borderRadius: BorderRadius.circular(37),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isCheckIn ? Icons.login : Icons.logout,
                color: Colors.white,
                size: widget.screenWidth * 0.013,
              ),
              SizedBox(width: widget.screenWidth * 0.004),
              Text(
                widget.isCheckIn ? 'Check In' : 'Check Out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.screenWidth * 0.011,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
