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
  DateTime _currentTime = DateTime.now();
  
  // Cache untuk menghindari rebuild berlebihan
  List<BookingModel>? _cachedBookings;
  List<BookingModel>? _cachedTodayBookings;
  
  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    debugPrint('🚀 RoomDetailsScreen initState: Room ID = ${widget.room.id}');
    debugPrint('🔥 Using REAL-TIME stream - auto-sync enabled!');
    
    // Update current time every second
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
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
    super.dispose();
  }

  String _getCurrentTimeString() {
    return '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _getFormattedDate() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[_currentTime.weekday - 1]}, ${_currentTime.day} ${months[_currentTime.month - 1]} ${_currentTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Check if user has Bookings role - ONLY Bookings role allowed
        if (authProvider.user == null || authProvider.userModel?.role != UserRole.booking) {
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
                        backgroundColor: AppColors.primaryRed,
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
                    image: Assets.images.tabScreen.provider(),
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
                                  color: Colors.white.withOpacity(0.5),
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
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                              color: Colors.white.withOpacity(0.5),
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                border: Border.all(color: Colors.white, width: 2),
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
                        color: Colors.white,
                        size: screenWidth * 0.029,
                      ),
                      
                      SizedBox(width: screenWidth * 0.015),
                      
                      // Time and Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getCurrentTimeString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.03,
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _getFormattedDate(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.0125,
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Available Status
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.015,
                          vertical: screenHeight * 0.025,
                        ),
                        decoration: BoxDecoration(
                          color: widget.room.isAvailable 
                              ? const Color(0xFFE3FFDF)
                              : const Color(0xFFFFDFDF),
                          border: Border.all(
                            color: widget.room.isAvailable
                                ? const Color(0xFF16BC00)
                                : const Color(0xFFEC0303),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.room.isAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: widget.room.isAvailable
                                  ? const Color(0xFF16BC00)
                                  : const Color(0xFFEC0303),
                              size: screenWidth * 0.025,
                            ),
                            SizedBox(width: screenWidth * 0.006),
                            Text(
                              widget.room.isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: screenWidth * 0.015,
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: screenHeight * 0.03),
                  
                  Divider(color: Colors.white, thickness: 2),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  // Booked Schedule Title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Booked Schedule',
                      style: TextStyle(
                        color: Colors.white,
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
        
        // Update cache jika ada perubahan
        if (_hasBookingsChanged(allBookings)) {
          _cachedBookings = allBookings;
          _cachedTodayBookings = _filterBookingsForToday(allBookings);
        }
        
        final bookings = _cachedTodayBookings ?? [];
        return Stack(
          children: [
            // Bookings List dengan smooth updates
            bookings.isEmpty
                ? Center(
                    child: Text(
                      'No bookings for today',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: screenWidth * 0.012,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: bookings.length,
                    padding: EdgeInsets.only(bottom: screenHeight * 0.15),
                    // Disable default animations untuk menghindari flicker
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      
                      // Determine booking status color
                      Color borderColor;
                      Color statusBgColor;
                      String statusText;
                      
                      final now = DateTime.now();
                      final bookingStart = DateTime(
                        booking.bookingDate.year,
                        booking.bookingDate.month,
                        booking.bookingDate.day,
                        int.parse(booking.checkInTime.split(':')[0]),
                        int.parse(booking.checkInTime.split(':')[1]),
                      );
                      final bookingEnd = DateTime(
                        booking.bookingDate.year,
                        booking.bookingDate.month,
                        booking.bookingDate.day,
                        int.parse(booking.checkOutTime.split(':')[0]),
                        int.parse(booking.checkOutTime.split(':')[1]),
                      );
                      
                      if (now.isBefore(bookingStart)) {
                        // Upcoming
                        borderColor = const Color(0xFF16BC00);
                        statusBgColor = const Color(0xFF129E00);
                        statusText = 'Upcoming';
                      } else if (now.isAfter(bookingEnd)) {
                        // Completed
                        borderColor = const Color(0xFFEC0303);
                        statusBgColor = const Color(0xFFEC0303);
                        statusText = 'Completed';
                      } else {
                        // Ongoing
                        borderColor = const Color(0xFFF2C338);
                        statusBgColor = const Color(0xFFFFBF00);
                        statusText = 'Ongoing';
                      }
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                        padding: EdgeInsets.all(screenWidth * 0.012),
                        decoration: BoxDecoration(
                          color: const Color(0xBF170F0F),
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          children: [
                            // Left border indicator
                            Container(
                              width: 3,
                              height: screenHeight * 0.06,
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
                                  Text(
                                    '${booking.checkInTime}-${booking.checkOutTime}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: screenWidth * 0.0112,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.005),
                                  Text(
                                    'Booking ID #${booking.id.substring(0, 8).toUpperCase()} | Booked by ${booking.userName ?? "Unknown"}',
                                    style: TextStyle(
                                      color: const Color(0xFFBCBCBC),
                                      fontSize: screenWidth * 0.0087,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Status Badge
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
                                  color: Colors.white,
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
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _showBookingDialog,
                child: Center(
                  child: Assets.icon.addBook.svg(
                    width: screenWidth * 0.057,
                    height: screenWidth * 0.057,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  void _showBookingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BookingFormWidget(
        room: widget.room,
        // No callback needed - Stream auto-updates!
      ),
    );
  }
}

class _BookingFormWidget extends StatefulWidget {
  final RoomModel room;

  const _BookingFormWidget({
    required this.room,
  });

  @override
  State<_BookingFormWidget> createState() => _BookingFormWidgetState();
}

class _BookingFormWidgetState extends State<_BookingFormWidget> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  int _durationMinutes = 60;
  int _guestCount = 1;
  late TextEditingController _customDurationController;
  late TextEditingController _purposeController;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _customDurationController = TextEditingController();
    _purposeController = TextEditingController();
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  TimeOfDay _calculateEndTime() {
    final minutes = int.tryParse(_customDurationController.text) ?? _durationMinutes;
    final totalMinutes = _startTime.hour * 60 + _startTime.minute + minutes;
    final hours = (totalMinutes ~/ 60) % 24;
    final mins = totalMinutes % 60;
    return TimeOfDay(hour: hours, minute: mins);
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleBooking() async {
    if (!widget.room.isAvailable) {
      _showErrorSnackBar(
        title: 'Room Not Available',
        message: 'This room is currently not available for booking.',
      );
      return;
    }

    // Validate selected date is not in the past
    final now = DateTime.now();
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    
    if (selectedDateOnly.isBefore(todayOnly)) {
      _showErrorSnackBar(
        title: 'Invalid Date',
        message: 'Cannot book dates in the past. Please select today or a future date.',
      );
      return;
    }

    // Validate time is not in the past (only for today's booking)
    if (selectedDateOnly.isAtSameMomentAs(todayOnly)) {
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final currentTimeInMinutes = currentHour * 60 + currentMinute;
      final selectedTimeInMinutes = _startTime.hour * 60 + _startTime.minute;
      
      if (selectedTimeInMinutes < currentTimeInMinutes) {
        _showErrorSnackBar(
          title: 'Time Already Passed',
          message: 'Cannot book times that have already passed. Current time is ${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}. Please select a later time.',
        );
        return;
      }
    }

    // Validate guest count
    if (_guestCount > widget.room.maxGuests) {
      _showErrorSnackBar(
        title: 'Exceeds Capacity',
        message: 'Number of guests (${_guestCount}) exceeds room capacity (${widget.room.maxGuests}).',
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      if (authProvider.user == null) {
        throw 'User not authenticated. Please login again.';
      }

      final endTime = _calculateEndTime();

      debugPrint('🔍 Attempting booking:');
      debugPrint('   Room ID: ${widget.room.id}');
      debugPrint('   Date: ${_selectedDate.toString().split(' ')[0]}');
      debugPrint('   Time: ${_timeToString(_startTime)} - ${_timeToString(endTime)}');
      debugPrint('   Guests: $_guestCount');

      final bookingId = await bookingProvider.createBooking(
        userId: authProvider.user!.uid,
        roomId: widget.room.id,
        bookingDate: _selectedDate,
        checkInTime: _timeToString(_startTime),
        checkOutTime: _timeToString(endTime),
        numberOfGuests: _guestCount,
        purpose: _purposeController.text.isNotEmpty ? _purposeController.text : null,
      );

      // Check if booking creation failed
      if (bookingId == null) {
        final errorMsg = bookingProvider.errorMessage ?? 'Unknown error occurred';
        throw errorMsg;
      }

      debugPrint('✅ Booking created successfully with ID: $bookingId');

      if (mounted) {
        _showSuccessSnackBar(
          title: 'Booking Confirmed!',
          message: '${widget.room.name}\n${_timeToString(_startTime)} - ${_timeToString(endTime)}\n$_guestCount guest${_guestCount > 1 ? 's' : ''}',
        );
        
        debugPrint('🔥 Booking saved! Stream will auto-update all devices...');
        
        // Close dialog after showing success message
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      
      final errorString = e.toString();
      String title = 'Booking Failed';
      String message = 'An unexpected error occurred.';

      if (errorString.contains('not available for the selected')) {
        title = 'Time Slot Unavailable';
        message = 'This time slot is already booked.\nPlease select another time or date.';
      } else if (errorString.contains('exceeds room capacity')) {
        title = 'Capacity Exceeded';
        message = 'Too many guests for this room.\nPlease reduce guest count.';
      } else if (errorString.contains('Room not found')) {
        title = 'Room Not Found';
        message = 'This room no longer exists.\nPlease try another room.';
      } else if (errorString.contains('not authenticated')) {
        title = 'Authentication Error';
        message = 'You are not logged in. Please login and try again.';
      } else if (errorString.contains('permission-denied')) {
        title = 'Permission Denied';
        message = 'You do not have permission to create bookings.';
      } else {
        message = errorString.replaceAll('Exception: ', '').replaceAll('Error creating booking: ', '');
      }

      if (mounted) {
        _showErrorSnackBar(title: title, message: message);
      }
    } finally {
      setState(() => _isBooking = false);
    }
  }

  void _showSuccessSnackBar({
    required String title,
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar({
    required String title,
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _durationButton(int minutes, String label) {
    final isCustom = _customDurationController.text.isNotEmpty;
    final isSelected = (!isCustom && _durationMinutes == minutes) ||
        (isCustom && int.tryParse(_customDurationController.text) == minutes);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _durationMinutes = minutes;
            _customDurationController.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryRed : Colors.white,
            border: Border.all(
              color: AppColors.primaryRed,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected ? Colors.white : AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _calculateEndTime();
    final displayDuration = _customDurationController.text.isNotEmpty
        ? int.tryParse(_customDurationController.text) ?? _durationMinutes
        : _durationMinutes;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Book ${widget.room.name}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryRed,
                      ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Date Selection
            Text(
              'Select Date',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                // Calculate dates for picker
                final today = DateTime.now();
                final todayOnly = DateTime(today.year, today.month, today.day);
                
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: todayOnly, // Only allow today and future dates
                  lastDate: todayOnly.add(const Duration(days: 90)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Start Time Selection
            Text(
              'Start Time',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (picked != null) {
                  setState(() => _startTime = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      _timeToString(_startTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Duration Selection
            Text(
              'Duration',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _durationButton(30, '30 min'),
                const SizedBox(width: 8),
                _durationButton(60, '60 min'),
                const SizedBox(width: 8),
                _durationButton(90, '90 min'),
              ],
            ),
            const SizedBox(height: 12),

            // Custom Duration
            Text(
              'Custom Duration (minutes)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _customDurationController,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Enter custom duration',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryRedLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryRedLight.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Summary',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slot:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${_timeToString(_startTime)} - ${_timeToString(endTime)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRed,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '$displayDuration minutes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Guest Count
            Text(
              'Guests',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _guestCount > 1
                        ? () => setState(() => _guestCount--)
                        : null,
                  ),
                  Text(
                    _guestCount.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _guestCount < widget.room.maxGuests
                        ? () => setState(() => _guestCount++)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Purpose (optional)
            Text(
              'Purpose (optional)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _purposeController,
              decoration: InputDecoration(
                hintText: 'e.g., Meeting, Training, Class',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.room.isAvailable && !_isBooking
                    ? _handleBooking
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  disabledBackgroundColor: AppColors.borderColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isBooking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Confirm Booking',
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
