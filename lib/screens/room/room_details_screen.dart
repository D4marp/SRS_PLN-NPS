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
    
    // Update availability status every 8 seconds
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
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

  // Check if room is currently available based on bookings
  bool _isRoomCurrentlyAvailable(List<BookingModel> todayBookings) {
    final now = DateTime.now();
    
    // Check if there's any ongoing booking
    for (var booking in todayBookings) {
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
      
      // If current time is between booking start and end, room is unavailable
      if (now.isAfter(bookingStart) && now.isBefore(bookingEnd)) {
        return false;
      }
    }
    
    return true; // No ongoing bookings, room is available
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
                      
                      // Available Status - Based on actual bookings
                      _buildAvailabilityStatus(screenWidth, screenHeight),
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

  Widget _buildAvailabilityStatus(double screenWidth, double screenHeight) {
    return StreamBuilder<List<BookingModel>>(
      stream: context.read<BookingProvider>().getBookingsByRoomIdStream(widget.room.id),
      builder: (context, snapshot) {
        bool isAvailable = true;
        
        if (snapshot.hasData && snapshot.data != null) {
          isAvailable = _isRoomCurrentlyAvailable(snapshot.data!);
        }
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.015,
            vertical: screenHeight * 0.025,
          ),
          decoration: BoxDecoration(
            color: isAvailable 
                ? const Color(0xFFE3FFDF)
                : const Color(0xFFFFDFDF),
            border: Border.all(
              color: isAvailable
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
                isAvailable
                    ? Icons.check_circle
                    : Icons.cancel,
                color: isAvailable
                    ? const Color(0xFF16BC00)
                    : const Color(0xFFEC0303),
                size: screenWidth * 0.025,
              ),
              SizedBox(width: screenWidth * 0.006),
              Text(
                isAvailable ? 'Available' : 'Unavailable',
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
                onTap: () => _showBookingDialog(context),
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
