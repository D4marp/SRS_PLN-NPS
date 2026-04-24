import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../core/gen/assets.gen.dart';

class BookingFormScreen extends StatefulWidget {
  final RoomModel room;

  const BookingFormScreen({
    super.key,
    required this.room,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  int _durationMinutes = 90;
  int _guestCount = 1;
  late TextEditingController _customDurationController;
  late TextEditingController _purposeController;
  bool _isBooking = false;
  late Timer _timeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _customDurationController = TextEditingController();
    _purposeController = TextEditingController();
    
    // Set start time to current time
    final now = DateTime.now();
    _startTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    // Update time every second for realtime display
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _startTime = TimeOfDay(hour: now.hour, minute: now.minute);
        });
      }
    });
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    _purposeController.dispose();
    _timeUpdateTimer.cancel();
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

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return monthNames[month - 1];
  }

  Future<void> _handleBooking() async {
    if (!widget.room.isAvailable) {
      _showErrorSnackBar(
        title: 'Room Not Available',
        message: 'This room is currently not available for booking.',
      );
      return;
    }

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

    if (_guestCount > widget.room.maxGuests) {
      _showErrorSnackBar(
        title: 'Exceeds Capacity',
        message: 'Number of guests ($_guestCount) exceeds room capacity (${widget.room.maxGuests}).',
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      if (authProvider.userModel == null) {
        throw 'User not authenticated. Please login again.';
      }

      final endTime = _calculateEndTime();

      debugPrint('🔍 Attempting booking:');
      debugPrint('   Room ID: ${widget.room.id}');
      debugPrint('   Date: ${_selectedDate.toString().split(' ')[0]}');
      debugPrint('   Time: ${_timeToString(_startTime)} - ${_timeToString(endTime)}');
      debugPrint('   Guests: $_guestCount');

      final bookingId = await bookingProvider.createBooking(
        userId: authProvider.userId!,
        roomId: widget.room.id,
        bookingDate: _selectedDate,
        checkInTime: _timeToString(_startTime),
        checkOutTime: _timeToString(endTime),
        numberOfGuests: _guestCount,
        purpose: _purposeController.text.isNotEmpty ? _purposeController.text : null,
      );

      if (bookingId == null) {
        final errorMsg = bookingProvider.errorMessage ?? 'Unknown error occurred';
        throw errorMsg;
      }

      debugPrint('✅ Booking created successfully with ID: $bookingId');

      if (mounted) {
        _showSuccessSnackBar(
          title: 'Booking Confirmed!',
          message: 'Your booking has been successfully created.',
        );
        
        debugPrint('🔥 Booking saved! Stream will auto-update all devices...');
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
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
      if (mounted) {
        setState(() => _isBooking = false);
      }
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.error, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
            if (minutes == 0) {
              // Custom button - just to mark selection
              _durationMinutes = 0;
            } else {
              _durationMinutes = minutes;
              _customDurationController.clear();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: (minutes != 0 && isSelected) ? AppColors.primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: (minutes != 0 && isSelected) ? Colors.white : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: (minutes != 0 && isSelected) ? Colors.white : Colors.white,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    final currentMonth = _selectedDate.month;
    final currentYear = _selectedDate.year;
    
    final firstDay = DateTime(currentYear, currentMonth, 1);
    final lastDay = DateTime(currentYear, currentMonth + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    final days = <int>[];
    for (int i = 1; i < firstWeekday; i++) {
      days.add(0);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(i);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getMonthName(currentMonth)} $currentYear',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Inter',
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _selectedDate = DateTime(
                        currentYear,
                        currentMonth - 1,
                        _selectedDate.day.clamp(1, 28),
                      ),
                    ),
                    child: Icon(Icons.chevron_left, color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _selectedDate = DateTime(
                        currentYear,
                        currentMonth + 1,
                        _selectedDate.day.clamp(1, 28),
                      ),
                    ),
                    child: Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Column(
            children: [
              for (int i = 0; i < days.length; i += 7)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (int j = 0; j < 7 && i + j < days.length; j++)
                        GestureDetector(
                          onTap: days[i + j] == 0
                              ? null
                              : () => setState(
                                () => _selectedDate = DateTime(
                                  currentYear,
                                  currentMonth,
                                  days[i + j],
                                ),
                              ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: days[i + j] == _selectedDate.day &&
                                      currentMonth == _selectedDate.month &&
                                      currentYear == _selectedDate.year
                                  ? AppColors.primaryRed
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                days[i + j] == 0 ? '' : '${days[i + j]}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: days[i + j] == 0
                                      ? Colors.transparent
                                      : days[i + j] == _selectedDate.day &&
                                              currentMonth == _selectedDate.month &&
                                              currentYear == _selectedDate.year
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _calculateEndTime();
    final displayDuration = _customDurationController.text.isNotEmpty
        ? int.tryParse(_customDurationController.text) ?? _durationMinutes
        : _durationMinutes;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.userModel == null || authProvider.userModel?.role != UserRole.booking) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only users with Bookings role can access this page',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Book ${widget.room.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            centerTitle: false,
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: Assets.images.tabScreen.provider(),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Two column layout: Calendar on left, Form fields on right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Calendar
                          Expanded(
                            flex: 1,
                            child: _buildCalendarWidget(),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          // Right Column: Form fields
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Duration Section
                                Text(
                                  'Duration',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    _durationButton(60, '60 minutes'),
                                    const SizedBox(width: AppSpacing.sm),
                                    _durationButton(90, '90 minutes'),
                                    const SizedBox(width: AppSpacing.sm),
                                    _durationButton(120, '120 minutes'),
                                    const SizedBox(width: AppSpacing.sm),
                                    _durationButton(0, 'Custom'),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Purpose Section
                                Text(
                                  'Purpose (optional)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: TextField(
                                    controller: _purposeController,
                                    maxLines: 4,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontFamily: 'Plus Jakarta Sans',
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Meeting, Training, Class ...',
                                      hintStyle: TextStyle(
                                        color: Colors.black.withOpacity(0.4),
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Guest Count Section
                                Text(
                                  'Number of guest',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: _guestCount > 1
                                            ? () => setState(() => _guestCount--)
                                            : null,
                                        child: Text(
                                          '−',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primaryRed,
                                            fontFamily: 'Plus Jakarta Sans',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Text(
                                        '$_guestCount',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      GestureDetector(
                                        onTap: _guestCount < widget.room.maxGuests
                                            ? () => setState(() => _guestCount++)
                                            : null,
                                        child: Text(
                                          '+',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w500,
                                            color: _guestCount < widget.room.maxGuests
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.white.withOpacity(0.3),
                                            fontFamily: 'Plus Jakarta Sans',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Booking Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Booking Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date / Time',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Duration',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Guest',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'Plus Jakarta Sans',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ': ${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year} / ${_timeToString(_startTime)}-${_timeToString(endTime)}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        ': $displayDuration minutes',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        ': $_guestCount people',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Book Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isBooking ? null : _handleBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
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
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Book Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
