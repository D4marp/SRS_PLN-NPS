import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../providers/room_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class BookingOnlyScreen extends StatefulWidget {
  final RoomModel? selectedRoom;

  const BookingOnlyScreen({super.key, this.selectedRoom});

  @override
  State<BookingOnlyScreen> createState() => _BookingOnlyScreenState();
}

class _BookingOnlyScreenState extends State<BookingOnlyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RoomModel> _rooms = [];
  Map<String, List<BookingModel>> _roomBookings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRooms();
    });
  }

  Future<void> _loadRooms() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    await roomProvider.loadRooms();

    if (mounted) {
      setState(() {
        _rooms = roomProvider.allRooms;

        // If selectedRoom is provided, show only that room
        if (widget.selectedRoom != null) {
          _rooms = [widget.selectedRoom!];
        }

        if (_rooms.isNotEmpty) {
          _tabController = TabController(length: _rooms.length, vsync: this);
          _loadBookingsForRooms(bookingProvider);
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookingsForRooms(BookingProvider bookingProvider) async {
    for (var room in _rooms) {
      try {
        final bookings = await bookingProvider.getBookingsByRoomId(room.id);
        debugPrint('✅ Loaded ${bookings.length} bookings for room ${room.name} (${room.id})');
        for (var booking in bookings) {
          debugPrint('   - ${booking.checkInTime} to ${booking.checkOutTime} | Status: ${booking.status.name}');
        }
        if (mounted) {
          setState(() {
            _roomBookings[room.id] = bookings;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _roomBookings[room.id] = [];
          });
        }
        debugPrint('❌ Error loading bookings for room ${room.id}: $e');
      }
    }
  }

  List<BookingModel> _getTodayBookings(String roomId) {
    final bookings = _roomBookings[roomId] ?? [];

    try {
      // Sort by checkInTime and return all bookings for this room
      return bookings
        ..sort((a, b) {
          try {
            final aHour = int.parse(a.checkInTime.split(':')[0]);
            final aMin = int.parse(a.checkInTime.split(':')[1]);
            final bHour = int.parse(b.checkInTime.split(':')[0]);
            final bMin = int.parse(b.checkInTime.split(':')[1]);

            final aTotal = aHour * 60 + aMin;
            final bTotal = bHour * 60 + bMin;
            return aTotal.compareTo(bTotal);
          } catch (e) {
            debugPrint('Error comparing booking times: $e');
            return 0;
          }
        });
    } catch (e) {
      debugPrint('Error filtering bookings: $e');
      return [];
    }
  }

  @override
  void dispose() {
    if (_rooms.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Book a Room'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
          ),
        ),
        backgroundColor: Colors.white,
      );
    }

    if (_rooms.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Book a Room'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRooms,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.meeting_room_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Rooms Available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add rooms from admin panel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _loadRooms,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // AppBar with TabBar
              AppBar(
                title: const Text('Book a Room'),
                backgroundColor: Colors.white,
                elevation: 0,
                foregroundColor: Colors.black87,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadRooms,
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: AppColors.primaryRed,
                        unselectedLabelColor: AppColors.secondaryText,
                        indicatorColor: AppColors.primaryRed,
                        indicatorWeight: 3,
                        tabAlignment: TabAlignment.start,
                        tabs: _rooms.map((room) {
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRoomIcon(room.roomClass),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  room.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _rooms.map((room) {
                    return _buildRoomDetailScreen(room);
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomDetailScreen(RoomModel room) {
    return Scaffold(
      body: Stack(
        children: [
          _buildRoomDetails(room),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBookButton(room),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomDetails(RoomModel room) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _buildReservaHeader(room),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildScheduleSection(room),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _buildQuickInfoChips(room),
          ),
        ],
      ),
    );
  }

  Widget _buildReservaHeader(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: room.isAvailable
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : [const Color(0xFFB71C1C), const Color(0xFF8B0000)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            room.roomClass,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${room.location}, ${room.city}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: room.isAvailable
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: room.isAvailable
                    ? Colors.green.withOpacity(0.7)
                    : Colors.red.withOpacity(0.7),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  room.isAvailable ? Icons.check_circle : Icons.cancel,
                  color: room.isAvailable ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  room.isAvailable ? 'Available' : 'Booked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(RoomModel room) {
    final borderColor = room.isAvailable ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppColors.primaryText, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildScheduleList(room),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(RoomModel room) {
    final bookings = _getTodayBookings(room.id);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              color: Colors.grey.shade300,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'No bookings available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Room is available for booking',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time slot
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.primaryRed,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${booking.checkInTime} - ${booking.checkOutTime}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Guest count
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: AppColors.secondaryText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${booking.numberOfGuests} guest${booking.numberOfGuests > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
                if (booking.purpose != null && booking.purpose!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.description,
                        color: AppColors.secondaryText,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.purpose!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryText,
                                fontSize: 13,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getStatusColor(booking.status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    booking.status.toString().split('.').last.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _getStatusColor(booking.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.rejected:
        return Colors.red.shade800;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  Widget _buildQuickInfoChips(RoomModel room) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoChip(
            icon: Icons.people,
            label: 'Capacity',
            value: '${room.maxGuests}',
            room: room,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildInfoChip(
            icon: room.hasAC ? Icons.ac_unit : Icons.wind_power,
            label: 'Climate',
            value: room.hasAC ? 'AC' : 'Fan',
            room: room,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required RoomModel room,
  }) {
    final borderColor = room.isAvailable ? Colors.green.shade700 : Colors.red.shade700;
    final bgColor = room.isAvailable ? Colors.green.shade900 : Colors.red.shade900;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: room.isAvailable
              ? () => _showBookingDialog(room)
              : null,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Book Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: room.isAvailable
                ? AppColors.primaryRed
                : Colors.grey.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  void _showBookingDialog(RoomModel room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BookingFormWidget(room: room),
    );
  }

  IconData _getRoomIcon(String roomClass) {
    switch (roomClass.toLowerCase()) {
      case 'meeting room':
        return Icons.groups;
      case 'conference room':
        return Icons.business;
      case 'class room':
        return Icons.school;
      case 'lecture hall':
        return Icons.theater_comedy;
      case 'training room':
        return Icons.model_training;
      case 'board room':
        return Icons.dashboard;
      case 'study room':
        return Icons.menu_book;
      case 'lab':
        return Icons.science;
      default:
        return Icons.meeting_room;
    }
  }
}

class _BookingFormWidget extends StatefulWidget {
  final RoomModel room;

  const _BookingFormWidget({required this.room});

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
  late TextEditingController _bookedForNameController;
  late TextEditingController _bookedForCompanyController;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _customDurationController = TextEditingController();
    _purposeController = TextEditingController();
    _bookedForNameController = TextEditingController();
    _bookedForCompanyController = TextEditingController();
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    _purposeController.dispose();
    _bookedForNameController.dispose();
    _bookedForCompanyController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This room is not available'),
          backgroundColor: AppColors.errorRedDark,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();

      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final endTime = _calculateEndTime();

      await bookingProvider.createBooking(
        userId: authProvider.userId!.uid,
        roomId: widget.room.id,
        bookingDate: _selectedDate,
        checkInTime: _timeToString(_startTime),
        checkOutTime: _timeToString(endTime),
        numberOfGuests: _guestCount,
        bookedForName: _bookedForNameController.text.trim().isNotEmpty
            ? _bookedForNameController.text.trim()
            : null,
        bookedForCompany: _bookedForCompanyController.text.trim().isNotEmpty
            ? _bookedForCompanyController.text.trim()
            : null,
        purpose: _purposeController.text.isNotEmpty ? _purposeController.text : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking confirmed! ✓'),
            backgroundColor: AppColors.successGreenDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString()}'),
            backgroundColor: AppColors.errorRedDark,
          ),
        );
      }
    } finally {
      setState(() => _isBooking = false);
    }
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
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
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

            // Booking recipient (optional)
            Text(
              'Booked For (optional)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bookedForNameController,
              decoration: InputDecoration(
                hintText: 'Recipient name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bookedForCompanyController,
              decoration: InputDecoration(
                hintText: 'Company / organization',
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
