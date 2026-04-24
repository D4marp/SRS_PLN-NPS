import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';

/// Professional calendar view for managing bookings
/// Features: Monthly calendar view, date selection, status filtering, booking details
class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<BookingModel>> _bookingsByDate;
  BookingStatus? _selectedStatus;

  static const List<(BookingStatus, Color, String)> statusOptions = [
    (BookingStatus.pending, Color(0xFFF59E0B), 'Pending'),
    (BookingStatus.confirmed, Color(0xFF16A34A), 'Confirmed'),
    (BookingStatus.rejected, Color(0xFFDC2626), 'Rejected'),
    (BookingStatus.cancelled, Color(0xFF6B7280), 'Cancelled'),
    (BookingStatus.completed, Color(0xFF0EA5E9), 'Completed'),
  ];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _bookingsByDate = {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  void _loadBookings() {
    final bookings = context.read<AdminProvider>().bookings;
    _bookingsByDate.clear();
    for (var booking in bookings) {
      final date = DateTime(
        booking.bookingDate.year,
        booking.bookingDate.month,
        booking.bookingDate.day,
      );
      _bookingsByDate.putIfAbsent(date, () => []).add(booking);
    }
    setState(() {});
  }

  List<BookingModel> _getBookingsForDay(DateTime day) {
    final dayBookings = _bookingsByDate[
        DateTime(day.year, day.month, day.day)] ??
        [];
    if (_selectedStatus == null) {
      return dayBookings;
    }
    return dayBookings
        .where((b) => b.status == _selectedStatus)
        .toList();
  }

  Color _getStatusColor(BookingStatus status) {
    return statusOptions
        .firstWhere((e) => e.$1 == status)
        .$2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,

        title: const Text(
          'Booking Calendar',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status filter chips
              _buildStatusFilter(),
              const SizedBox(height: 20),

              // Calendar
              _buildCalendar(),
              const SizedBox(height: 24),

              // Bookings for selected day
              _buildSelectedDayBookings(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All button
          _statusFilterChip(
            label: 'All',
            isSelected: _selectedStatus == null,
            onTap: () {
              setState(() => _selectedStatus = null);
            },
          ),
          const SizedBox(width: 8),
          // Status filter buttons
          ...statusOptions.map(
            (status, color, label) => _statusFilterChip(
              label: label,
              color: color,
              isSelected: _selectedStatus == status,
              onTap: () {
                setState(
                  () => _selectedStatus =
                      _selectedStatus == status ? null : status,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Color(0xFFE5E7EB))
              : Colors.white,
          border: Border.all(
            color: isSelected
                ? (color ?? Color(0xFFD1D5DB))
                : Color(0xFFD1D5DB),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppColors.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: TableCalendar<BookingModel>(
        firstDay: DateTime(2024),
        lastDay: DateTime(2026),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarStyle: CalendarStyle(
          // Default cell styling
          defaultDecoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          defaultTextStyle: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          // Selected day styling
          selectedDecoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(8),
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),

          // Today styling
          todayDecoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppColors.primaryRed, width: 1.5),
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),

          // Weekend styling
          weekendTextStyle: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          // Outside month styling
          outsideTextStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
          ),
          outsideDecoration: const BoxDecoration(
            color: Colors.transparent,
          ),

          // Disabled styling
          disabledDecoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          disabledTextStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 14,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppColors.primaryRed,
            size: 24,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppColors.primaryRed,
            size: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
          ),
        ),
        eventLoader: _getBookingsForDay,
        calendarBuilders:
            CalendarBuilders<BookingModel>(
          dowBuilder: (context, day) {
            final text =
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    [day.weekday - 1];
            return Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
          markerBuilder:
              (context, day, events) {
            if (events.isEmpty)
              return const SizedBox();

            final bookings =
                _getBookingsForDay(day);
            if (bookings.isEmpty)
              return const SizedBox();

            // Show colored dots for different statuses
            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: bookings
                    .take(2)
                    .map(
                      (booking) =>
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets
                                .symmetric(
                              horizontal: 1,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  _getStatusColor(
                                booking
                                    .status,
                              ),
                              shape:
                                  BoxShape
                                      .circle,
                            ),
                          ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedDayBookings() {
    final dayBookings =
        _getBookingsForDay(_selectedDay);
    final dayLabel =
        DateFormat('EEEE, MMMM d, yyyy')
            .format(_selectedDay);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          dayLabel,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (dayBookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              24,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFF9FAFB,
              ),
              borderRadius:
                  BorderRadius
                      .circular(12),
              border: Border.all(
                color: const Color(
                  0xFFE5E7EB,
                ),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'No bookings for this day',
                style: TextStyle(
                  color: AppColors
                      .secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...dayBookings.map(
            (booking) =>
                _buildBookingItem(
              booking,
            ),
          ),
      ],
    );
  }

  Widget _buildBookingItem(
    BookingModel booking,
  ) {
    final statusColor =
        _getStatusColor(booking.status);
    final statusLabel =
        booking.status.name
            .replaceRange(
              0,
              1,
              booking.status.name[0]
                  .toUpperCase(),
            );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // Room + Status row
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking
                        .roomName ??
                        'Unknown Room',
                    style:
                        const TextStyle(
                          color:
                              AppColors
                                  .primaryText,
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        10,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        statusColor
                            .withOpacity(
                      0.1,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      6,
                    ),
                    border:
                        Border.all(
                      color:
                          statusColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),

            // Location
            Row(
              children: [
                const Icon(
                  Icons
                      .location_on_outlined,
                  size: 14,
                  color: AppColors
                      .secondaryText,
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child: Text(
                    booking
                            .roomLocation ??
                        'N/A',
                    style:
                        TextStyle(
                          color: AppColors
                              .secondaryText,
                          fontSize: 13,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),

            // Time + Guests
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors
                      .secondaryText,
                ),
                const SizedBox(
                  width: 6,
                ),
                Text(
                  '${booking.checkInTime} - ${booking.checkOutTime}',
                  style: TextStyle(
                    color: AppColors
                        .secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: AppColors
                      .secondaryText,
                ),
                const SizedBox(
                  width: 6,
                ),
                Text(
                  '${booking.numberOfGuests} guest${booking.numberOfGuests != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: AppColors
                        .secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (booking
                .userName !=
                null) ...[
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Icon(
                    Icons
                        .person_outline,
                    size: 14,
                    color: AppColors
                        .secondaryText,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child: Text(
                      booking.userName!,
                      style:
                          TextStyle(
                            color: AppColors
                                .secondaryText,
                            fontSize: 13,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
