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
    debugPrint('🔥 Using EVENT-DRIVEN architecture - no continuous refresh!');
    
    // Initialize time notifier
    _timeNotifier = ValueNotifier<DateTime>(DateTime.now());
    
    // Initialize booking event controller
    _bookingEventController = StreamController<BookingUpdateEvent>.broadcast();
    
    // Update time every 8 seconds (only for UI display, no data reload)
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        _timeNotifier.value = DateTime.now();
      }
    });
  }

  List<BookingModel> _filterBookingsForToday(List<BookingModel> bookings) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    
    final filtered = bookings.where((booking) {
      final bookingDateOnly = DateTime(booking.bookingDate.year, booking.bookingDate.month, booking.bookingDate.day);
      return bookingDateOnly.isAtSameMomentAs(todayOnly);
    }).toList();
    
    return filtered;
  }

  // Helper untuk check apakah data booking berubah
  bool _hasBookingsChanged(List<BookingModel> newBookings) {
    if (_cachedBookings == null || newBookings.length != _cachedBookings!.length) {
      return true;
    }
    
    // Check setiap booking untuk perubahan
    for (int i = 0; i < newBookings.length; i++) {
      if (newBookings[i].id != _cachedBookings![i].id ||
          newBookings[i].status != _cachedBookings![i].status ||
          newBookings[i].checkInTime != _cachedBookings![i].checkInTime) {
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
  
  String _getFormattedDate(DateTime time) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[time.weekday - 1]}, ${time.day} ${months[time.month - 1]} ${time.year}';
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
        if (authProvider.userModel == null || authProvider.userModel?.role != UserRole.booking) {
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                      child: const Text('Go Back', style: TextStyle(fontSize: 16)),
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
                // Background Image
                Positioned.fill(
                  child: Image(
                    image: Assets.images.bgBooking.provider(),
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
                                  color: AppColors.secondaryText.withOpacity(0.7),
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
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryText),
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
                      color: AppColors.primaryText,
                      fontSize: screenWidth * 0.03,
                      fontFamily: 'Plus Jakarta Sans',
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
                      color: AppColors.secondaryText,
                      size: screenWidth * 0.017,
                    ),
                    SizedBox(width: screenWidth * 0.006),
                    Expanded(
                      child: Text(
                        '${widget.room.location}, ${widget.room.city}',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: screenWidth * 0.0125,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ],
                  ),
                  
                  SizedBox(height: screenHeight * 0.025),
                  
                  // Capacity
                  Text(
                    'Capacity:',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: screenWidth * 0.0125,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.012),
                
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.015,
                    vertical: screenHeight * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.025),
                  
                  // Facility
                  Text(
                    'Facility:',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: screenWidth * 0.0125,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.012),
                  
                  Wrap(
                  spacing: screenWidth * 0.008,
                  runSpacing: screenHeight * 0.015,
                  children: [
                    if (widget.room.hasAC)
                      _buildFacilityChip('AC', Icons.ac_unit, screenWidth),
                    if (widget.room.amenities.any((a) => a.toLowerCase().contains('projector')))
                      _buildFacilityChip('Projector', Icons.tv, screenWidth),
                    if (widget.room.amenities.any((a) => a.toLowerCase().contains('whiteboard') || a.toLowerCase().contains('interactive')))
                        _buildFacilityChip('Interactive Panel', Icons.touch_app, screenWidth),
                    ],
                  ),
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
                  Row(
                    children: [
                      // Clock Icon
                      Icon(
                        Icons.access_time,
                        color: AppColors.primaryText,
                        size: screenWidth * 0.029,
                      ),
                      
                      SizedBox(width: screenWidth * 0.015),
                      
                      // Time and Date
                      Expanded(
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _timeNotifier,
                          builder: (context, currentTime, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getCurrentTimeString(currentTime),
                                  style: TextStyle(
                                    color: AppColors.primaryText,
                                    fontSize: screenWidth * 0.03,
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _getFormattedDate(currentTime),
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: screenWidth * 0.0125,
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      
                      // Available Status - Based on actual bookings
                      _buildAvailabilityStatus(screenWidth, screenHeight),
                    ],
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
                        color: AppColors.primaryText,
                        fontSize: screenWidth * 0.0125,
                        fontFamily: 'Plus Jakarta Sans',
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

  Widget _buildFacilityChip(String label, IconData icon, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.015,
        vertical: screenWidth * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(108),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: screenWidth * 0.018,
            color: Colors.black,
          ),
          SizedBox(width: screenWidth * 0.006),
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: screenWidth * 0.0127,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStatus(double screenWidth, double screenHeight) {
    return StreamBuilder<List<BookingModel>>(
      stream: context.read<BookingProvider>().getBookingsByRoomIdStream(widget.room.id),
      builder: (context, snapshot) {
        return ValueListenableBuilder<DateTime>(
          valueListenable: _timeNotifier,
          builder: (context, currentTime, _) {
            bool isAvailable = true;
            
            if (snapshot.hasData && snapshot.data != null) {
              // Filter bookings for today only
              final todayBookings = _filterBookingsForToday(snapshot.data!);
              
              debugPrint('═══════════════════════════════════════');
              debugPrint('🔍 AVAILABILITY CHECK - ${_getCurrentTimeString(currentTime)}');
              debugPrint('═══════════════════════════════════════');
              debugPrint('📅 Today Date: ${currentTime.year}-${currentTime.month}-${currentTime.day}');
              debugPrint('🕐 Current Time: ${currentTime.hour}:${currentTime.minute.toString().padLeft(2, '0')}');
              debugPrint('📊 Today Bookings Count: ${todayBookings.length}');
              
              // Check if there's any ongoing booking
              for (var booking in todayBookings) {
                debugPrint('───────────────────────────────────────');
                debugPrint('📌 Booking ID: ${booking.id.substring(0, 8)}');
                debugPrint('   Booking Date: ${booking.bookingDate}');
                debugPrint('   Check-in Time: ${booking.checkInTime}');
                debugPrint('   Check-out Time: ${booking.checkOutTime}');
                
                try {
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
                    debugPrint('   ❌ Invalid scheduled times');
                    continue;
                  }
                  
                  debugPrint('   Parsed Start: $bookingStart');
                  debugPrint('   Parsed End: $bookingEnd');
                  debugPrint('   Now: $currentTime');

                    final effectiveStart = actualStart;
                    final effectiveEnd = actualEnd ?? bookingEnd;

                    final isAfterStart =
                      effectiveStart != null && currentTime.isAfter(effectiveStart);
                    final isBeforeEnd = currentTime.isBefore(effectiveEnd);
                    // Only occupied after actual check-in
                    final isOngoing = isAfterStart && isBeforeEnd;

                    debugPrint('   Is After Start: $isAfterStart');
                    debugPrint('   Is Before End: $isBeforeEnd');
                  debugPrint('   Is Ongoing: $isOngoing');
                  
                  if (isOngoing) {
                    debugPrint('   ✅ → OCCUPIED');
                    isAvailable = false;
                  } else {
                    debugPrint('   ❌ → Not ongoing');
                  }
                } catch (e) {
                  debugPrint('   ❌ Error parsing: $e');
                }
              }
              
              if (isAvailable && todayBookings.isNotEmpty) {
                debugPrint('───────────────────────────────────────');
                debugPrint('📊 All bookings checked - No ongoing');
              } else if (isAvailable && todayBookings.isEmpty) {
                debugPrint('───────────────────────────────────────');
                debugPrint('✨ No bookings today');
              }
              
              debugPrint('═══════════════════════════════════════');
              debugPrint('🎯 FINAL STATUS: ${isAvailable ? 'AVAILABLE ✅' : 'OCCUPIED ❌'}');
              debugPrint('═══════════════════════════════════════');
            }
            
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.015,
                vertical: screenHeight * 0.025,
              ),
              decoration: BoxDecoration(
                color: isAvailable 
                    ? const Color(0xFFE3FFDF)
                    : AppColors.warningYellowLight,
                border: Border.all(
                  color: isAvailable
                      ? const Color(0xFF16BC00)
                      : AppColors.warningYellow,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAvailable
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: isAvailable
                        ? const Color(0xFF16BC00)
                      : AppColors.warningYellow,
                    size: screenWidth * 0.025,
                  ),
                  SizedBox(width: screenWidth * 0.006),
                  Text(
                    isAvailable ? 'Available' : 'Occupied',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: screenWidth * 0.015,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
      stream: bookingProvider.getBookingsByRoomIdStream(widget.room.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryText),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading schedule',
              style: TextStyle(
                color: AppColors.secondaryText,
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
          debugPrint('📊 Schedule cache updated - Today bookings: ${_cachedTodayBookings?.length ?? 0}');
        }
        
        final bookings = _cachedTodayBookings ?? [];
        
        // Wrap dengan ValueListenableBuilder untuk status updates tanpa rebuild data
        return ValueListenableBuilder<DateTime>(
          valueListenable: _timeNotifier,
          builder: (context, currentTime, _) {
            return Stack(
              children: [
                // Bookings List
                bookings.isEmpty
                    ? Center(
                        child: Text(
                          'No bookings for today',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: screenWidth * 0.012,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: bookings.length,
                        padding: EdgeInsets.only(bottom: screenHeight * 0.15),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          
                          // Determine booking status based on currentTime
                          Color borderColor;
                          Color statusBgColor;
                          String statusText;
                          Color statusTextColor;
                          
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
                            borderColor = AppColors.secondaryText;
                            statusBgColor = AppColors.borderColorDark;
                            statusText = 'Invalid Time';
                            statusTextColor = AppColors.primaryText;
                          } else if (actualStart != null) {
                            final effectiveEnd = actualEnd ?? bookingEnd;

                            if (actualEnd != null && currentTime.isAfter(actualEnd)) {
                              // Completed after check-out
                              borderColor = AppColors.warningYellow;
                              statusBgColor = AppColors.warningYellow;
                              statusText = 'Completed';
                              statusTextColor = Colors.black;
                            } else if (currentTime.isAfter(actualStart) &&
                                currentTime.isBefore(effectiveEnd)) {
                              // Ongoing only after check-in
                              borderColor = const Color(0xFFF2C338);
                              statusBgColor = const Color(0xFFFFBF00);
                              statusText = 'Ongoing';
                              statusTextColor = Colors.black;
                            } else if (currentTime.isBefore(actualStart)) {
                              // Upcoming (check-in set in the future)
                              borderColor = const Color(0xFF16BC00);
                              statusBgColor = const Color(0xFF129E00);
                              statusText = 'Upcoming';
                              statusTextColor = Colors.white;
                            } else {
                              // Past the scheduled window without check-out
                              borderColor = AppColors.warningYellow;
                              statusBgColor = AppColors.warningYellow;
                              statusText = 'Completed';
                              statusTextColor = Colors.black;
                            }
                          } else if (currentTime.isBefore(bookingStart)) {
                            // Upcoming
                            borderColor = const Color(0xFF16BC00);
                            statusBgColor = const Color(0xFF129E00);
                            statusText = 'Upcoming';
                            statusTextColor = Colors.white;
                          } else if (currentTime.isAfter(bookingEnd)) {
                            // No check-in
                            borderColor = AppColors.secondaryText;
                            statusBgColor = AppColors.borderColorDark;
                            statusText = 'No Check-in';
                            statusTextColor = AppColors.primaryText;
                          } else {
                            // Awaiting check-in
                            borderColor = AppColors.secondaryBlue;
                            statusBgColor = AppColors.secondaryBlue;
                            statusText = 'Awaiting Check-in';
                            statusTextColor = Colors.white;
                          }
                          
                          final isAwaitingCheckIn = statusText == 'Awaiting Check-in';

                          return Container(
                            margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                            padding: EdgeInsets.all(screenWidth * 0.012),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              border: Border.all(color: AppColors.borderColorDark),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time range
                                      Text(
                                        '${booking.checkInTime} - ${booking.checkOutTime}',
                                        style: TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: screenWidth * 0.0112,
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.004),
                                      // Booker name
                                      Text(
                                        booking.userName ?? 'Unknown',
                                        style: TextStyle(
                                          color: AppColors.primaryText,
                                          fontSize: screenWidth * 0.0095,
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // For: bookedForName · company
                                      if (booking.bookedForName != null && booking.bookedForName!.isNotEmpty) ...[
                                        SizedBox(height: screenHeight * 0.002),
                                        Text(
                                          'For: ${booking.bookedForName}${booking.bookedForCompany != null && booking.bookedForCompany!.isNotEmpty ? ' · ${booking.bookedForCompany}' : ''}',
                                          style: TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: screenWidth * 0.0082,
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      // Guests & purpose
                                      SizedBox(height: screenHeight * 0.002),
                                      Row(
                                        children: [
                                          Icon(Icons.group, size: screenWidth * 0.011, color: AppColors.secondaryText),
                                          SizedBox(width: screenWidth * 0.003),
                                          Text(
                                            '${booking.numberOfGuests} tamu',
                                            style: TextStyle(
                                              color: AppColors.secondaryText,
                                              fontSize: screenWidth * 0.0082,
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (booking.purpose != null && booking.purpose!.isNotEmpty) ...[
                                            SizedBox(width: screenWidth * 0.008),
                                            Icon(Icons.info_outline, size: screenWidth * 0.011, color: AppColors.secondaryText),
                                            SizedBox(width: screenWidth * 0.003),
                                            Expanded(
                                              child: Text(
                                                booking.purpose!,
                                                style: TextStyle(
                                                  color: AppColors.secondaryText,
                                                  fontSize: screenWidth * 0.0082,
                                                  fontFamily: 'Plus Jakarta Sans',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Badge or Check-In Button
                                if (isAwaitingCheckIn)
                                  _CheckInButton(
                                    bookingId: booking.id,
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                  )
                                else
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.0062,
                                      vertical: screenHeight * 0.005,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(37),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusTextColor,
                                        fontSize: screenWidth * 0.0087,
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontWeight: FontWeight.w500,
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

class _CheckInButton extends StatefulWidget {
  final String bookingId;
  final double screenWidth;
  final double screenHeight;

  const _CheckInButton({
    required this.bookingId,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  State<_CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<_CheckInButton> {
  bool _isLoading = false;

  Future<void> _checkIn() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await ApiBookingService.submitCheckInCheckOut(
        bookingId: widget.bookingId,
        actualCheckInTime: timeStr,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in berhasil pukul $timeStr'),
            backgroundColor: const Color(0xFF16BC00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in gagal: $e'),
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
    return GestureDetector(
      onTap: _checkIn,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.screenWidth * 0.0062,
          vertical: widget.screenHeight * 0.005,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryBlue,
          borderRadius: BorderRadius.circular(37),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.login,
              color: Colors.white,
              size: widget.screenWidth * 0.013,
            ),
            SizedBox(width: widget.screenWidth * 0.004),
            Text(
              'Check In',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.screenWidth * 0.0087,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
