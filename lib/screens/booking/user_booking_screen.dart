import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/room_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/gen/assets.gen.dart';

class UserBookingScreen extends StatefulWidget {
  final RoomModel room;

  const UserBookingScreen({
    super.key,
    required this.room,
  });

  @override
  State<UserBookingScreen> createState() => _UserBookingScreenState();
}

class _UserBookingScreenState extends State<UserBookingScreen> {
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

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _calculateEndTime() {
    final minutes = int.tryParse(_customDurationController.text) ?? _durationMinutes;
    final totalMinutes = _startTime.hour * 60 + _startTime.minute + minutes;
    final hours = (totalMinutes ~/ 60) % 24;
    final mins = totalMinutes % 60;
    return TimeOfDay(hour: hours, minute: mins);
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
        
        debugPrint('🔥 Booking saved! Stream will auto-update all screens...');
        
        // Close screen after showing success message
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

  @override
  Widget build(BuildContext context) {
    final endTime = _calculateEndTime();
    final displayDuration = _customDurationController.text.isNotEmpty
        ? int.tryParse(_customDurationController.text) ?? _durationMinutes
        : _durationMinutes;

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient circles
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF170F0F),
            child: Stack(
              children: [
                // Top right gradient circle
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.4,
                  top: -191,
                  child: Container(
                    width: 504,
                    height: 504,
                    decoration: const ShapeDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.50, 0.50),
                        radius: 0.52,
                        colors: [Color(0xFF690011), Color(0xFF34000B)],
                      ),
                      shape: OvalBorder(
                        side: BorderSide(width: 2, color: Color(0xFFEC0303)),
                      ),
                    ),
                  ),
                ),
                // Top left gradient circle
                Positioned(
                  left: -78,
                  top: -426,
                  child: Container(
                    width: 504,
                    height: 504,
                    decoration: const ShapeDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.16, 0.82),
                        radius: 0.65,
                        colors: [Color(0xFF34000B), Color(0xFFAF0406)],
                      ),
                      shape: OvalBorder(
                        side: BorderSide(width: 2, color: Color(0xFFEC0303)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AppBar Custom
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Booking Details',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                    ),

                    // Main Room Image
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: ShapeDecoration(
                        image: widget.room.imageUrls.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(widget.room.imageUrls.first),
                                fit: BoxFit.cover,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: widget.room.imageUrls.isEmpty
                          ? const Center(
                              child: Icon(Icons.meeting_room, size: 80, color: Colors.white54),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Amenities Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAmenityChip(
                            icon: Assets.icon.guests.svg(width: 20, height: 20),
                            label: '${widget.room.maxGuests} Guests',
                          ),
                          const SizedBox(width: 8),
                          if (widget.room.hasAC)
                            _buildAmenityChip(
                              icon: const Icon(Icons.ac_unit, size: 20, color: Colors.black),
                              label: 'AC',
                            ),
                          const SizedBox(width: 8),
                          if (widget.room.amenities.any((a) => a.toLowerCase().contains('projector')))
                            _buildAmenityChip(
                              icon: const Icon(Icons.present_to_all, size: 20, color: Colors.black),
                              label: 'Projector',
                            ),
                          const SizedBox(width: 8),
                          if (widget.room.amenities.any((a) => a.toLowerCase().contains('panel') || a.toLowerCase().contains('interactive')))
                            _buildAmenityChip(
                              icon: const Icon(Icons.touch_app, size: 20, color: Colors.black),
                              label: 'Interactive Panel',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Room Name
                    Text(
                      widget.room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFBBBBBB), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.room.city}, ${widget.room.location}',
                          style: const TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 14,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Room Details Heading
                    const Text(
                      'Room Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Room Images Gallery (3 images)
                    Row(
                      children: [
                        Expanded(child: _buildGalleryImage(0)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildGalleryImage(1)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildGalleryImage(2)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Select Date Heading
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calendar Widget
                    _buildCalendarWidget(),
                    const SizedBox(height: 24),

                    // Select Time Heading
                    const Text(
                      'Select Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Display Row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (time != null) {
                                setState(() => _startTime = time);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: ShapeDecoration(
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(width: 1.5, color: Color(0xFFBBBBBB)),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.white, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_timeToString(_startTime)} - ${_timeToString(endTime)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(width: 1.5, color: Color(0xFFBBBBBB)),
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '$displayDuration minutes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

              // Purpose (optional)
              const Text(
                'Purpose (optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 122,
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1.5, color: Color(0xFFBBBBBB)),
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: TextField(
                  controller: _purposeController,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Meeting, Training, Class ...',
                    hintStyle: TextStyle(
                      color: Colors.black45,
                      fontSize: 16,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 4,
                  minLines: 4,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              const SizedBox(height: 30),

              // Book Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: ShapeDecoration(
                  color: widget.room.isAvailable && !_isBooking
                      ? const Color(0xFFEC0303)
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: widget.room.isAvailable && !_isBooking
                      ? _handleBooking
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
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
                      : const Text(
                          'Book now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build amenity chips
  Widget _buildAmenityChip({required Widget icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(75),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build gallery images
  Widget _buildGalleryImage(int index) {
    if (widget.room.imageUrls.length > index) {
      return Container(
        height: 106,
        decoration: ShapeDecoration(
          image: DecorationImage(
            image: CachedNetworkImageProvider(widget.room.imageUrls[index]),
            fit: BoxFit.cover,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return Container(
      height: 106,
      decoration: ShapeDecoration(
        color: const Color(0xFF939393).withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, color: Color(0xFFBBBBBB), size: 40),
      ),
    );
  }

  // Helper method to build inline calendar widget
  Widget _buildCalendarWidget() {
    final now = DateTime.now();
    final displayMonth = DateTime(_selectedDate.year, _selectedDate.month);
    final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
    final lastDayOfMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1.5, color: Color(0xFFBBBBBB)),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Month Header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(displayMonth),
                style: const TextStyle(
                  color: Color(0xFF0F0F0F),
                  fontSize: 22,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 26),
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 26),
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0F0F0F),
                          fontSize: 19,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const Divider(color: Color(0xFFE5E5E5), height: 20),

          // Calendar grid
          ...List.generate(6, (weekIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (dayIndex) {
                  final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 2;
                  final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
                  final date = isCurrentMonth
                      ? DateTime(displayMonth.year, displayMonth.month, dayNumber)
                      : null;
                  final isSelected = date != null &&
                      date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final isPast = date != null && date.isBefore(DateTime(now.year, now.month, now.day));

                  return GestureDetector(
                    onTap: isCurrentMonth && !isPast
                        ? () {
                            setState(() {
                              _selectedDate = date!;
                            });
                          }
                        : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: isSelected
                          ? const ShapeDecoration(
                              color: Color(0xFFEC0303),
                              shape: OvalBorder(),
                            )
                          : null,
                      child: Center(
                        child: Text(
                          isCurrentMonth ? dayNumber.toString() : '',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isPast
                                    ? const Color(0xFF939393)
                                    : isCurrentMonth
                                        ? const Color(0xFF0F0F0F)
                                        : const Color(0xFF939393),
                            fontSize: 19,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
