import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../models/room_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../utils/app_theme.dart';
import 'booking_calendar_screen.dart';

/// Professional industrial admin dashboard
/// Features: Statistics cards, booking overview, room management, quick actions
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      context
          .read<AdminProvider>()
          .loadStats();
      context
          .read<AdminProvider>()
          .loadBookings();
      context
          .read<RoomProvider>()
          .fetchRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.creamBackground,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Welcome section
              _buildWelcomeSection(),
              const SizedBox(height: 24),

              // Statistics cards (2x2 grid)
              _buildStatsGrid(),
              const SizedBox(height: 28),

              // Recent Bookings section
              _buildRecentBookingsSection(),
              const SizedBox(height: 28),

              // Room Status section
              _buildRoomStatusSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: const Text(
        'Admin Dashboard',
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme:
          const IconThemeData(
            color: AppColors.primaryText,
          ),
      actions: [
        Padding(
          padding:
              const EdgeInsets.only(
                right: 16,
              ),
          child: Center(
            child: Consumer<
                AuthProvider>(
              builder: (context,
                  authProvider, _) {
                return Text(
                  authProvider
                          .userModel
                          ?.name ??
                      'Admin',
                  style:
                      const TextStyle(
                        color: AppColors
                            .primaryText,
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final greeting =
        now.hour < 12
            ? 'Good Morning'
            : now.hour < 18
                ? 'Good Afternoon'
                : 'Good Evening';

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(
              color: AppColors.primaryRed,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat(
              'EEEE, MMMM d, yyyy',
            ).format(now),
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Consumer<
        AdminProvider>(
      builder: (context,
          adminProvider, _) {
        final stats = [
          (
            label: 'Total Bookings',
            value: '${adminProvider.totalBookings}',
            icon: Icons.event_note,
            color: const Color(
              0xFF0EA5E9,
            ),
          ),
          (
            label: 'Pending',
            value:
                '${adminProvider.pendingCount}',
            icon: Icons
                .hourglass_bottom,
            color: const Color(
              0xFFF59E0B,
            ),
          ),
          (
            label: 'Confirmed',
            value:
                '${adminProvider.confirmedCount}',
            icon:
                Icons
                    .check_circle,
            color: const Color(
              0xFF16A34A,
            ),
          ),
          (
            label: 'Total Rooms',
            value:
                '${adminProvider.totalRooms}',
            icon: Icons
                .meeting_room,
            color: AppColors
                .primaryRed,
          ),
        ];

        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          children: stats
              .map(
                (stat) =>
                    _buildStatCard(
                      label: stat
                          .$1,
                      value: stat
                          .$2,
                      icon: stat
                          .$3,
                      color: stat
                          .$4,
                    ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
          width: 1,
        ),
      ),
      padding:
          const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.1,
              ),
              borderRadius:
                  BorderRadius
                      .circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                      color: AppColors
                          .primaryText,
                      fontSize: 24,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                label,
                style:
                    TextStyle(
                      color: AppColors
                          .secondaryText,
                      fontSize: 12,
                      fontWeight:
                          FontWeight
                              .w500,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget
      _buildRecentBookingsSection() {
    return Consumer<
        AdminProvider>(
      builder: (context,
          adminProvider, _) {
        final recentBookings =
            adminProvider
                .bookings
                .take(3)
                .toList();

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // Header with action button
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Recent Bookings',
                  style: TextStyle(
                    color: AppColors
                        .primaryText,
                    fontSize: 16,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingCalendarScreen(),
                    ),
                  ),
                  child: Text(
                    'View All →',
                    style:
                        const TextStyle(
                          color: AppColors
                              .primaryRed,
                          fontSize: 13,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            if (recentBookings
                .isEmpty)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(24),
                decoration:
                    BoxDecoration(
                      color: const Color(
                        0xFFF9FAFB,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFE5E7EB,
                        ),
                        width: 1,
                      ),
                    ),
                child: Center(
                  child: Text(
                    'No bookings yet',
                    style:
                        TextStyle(
                          color: AppColors
                              .secondaryText,
                          fontSize: 14,
                        ),
                  ),
                ),
              )
            else
              ...recentBookings
                  .map(
                    (booking) =>
                        _buildBookingRow(
                      booking,
                    ),
                  )
                  .toList(),
          ],
        );
      },
    );
  }

  Widget
      _buildBookingRow(
    BookingModel booking,
  ) {
    final statusColor =
        _getStatusColor(
          booking.status,
        );
    final date =
        DateFormat('MMM d')
            .format(
          booking
              .bookingDate,
        );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius
                .circular(10),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(
              color:
                  statusColor
                      .withOpacity(
                0.1,
              ),
              borderRadius:
                  BorderRadius
                      .circular(6),
            ),
            child: Center(
              child: Icon(
                Icons
                    .event_note_outlined,
                size: 16,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  booking
                          .roomName ??
                      'Unknown',
                  style:
                      const TextStyle(
                        color: AppColors
                            .primaryText,
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '${booking.checkInTime} - ${booking.checkOutTime} • $date',
                  style:
                      TextStyle(
                        color: AppColors
                            .secondaryText,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets
                .symmetric(
              horizontal: 8,
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
                      .circular(6),
              border:
                  Border.all(
                color:
                    statusColor,
                width: 0.5,
              ),
            ),
            child: Text(
              booking.status.name,
              style:
                  TextStyle(
                    color:
                        statusColor,
                    fontSize: 11,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(
    BookingStatus status,
  ) {
    return switch (status) {
      BookingStatus.pending =>
        const Color(
          0xFFF59E0B,
        ),
      BookingStatus
          .confirmed =>
        const Color(
          0xFF16A34A,
        ),
      BookingStatus.rejected =>
        const Color(
          0xFFDC2626,
        ),
      BookingStatus
          .cancelled =>
        const Color(
          0xFF6B7280,
        ),
      BookingStatus
          .completed =>
        const Color(
          0xFF0EA5E9,
        ),
    };
  }

  Widget
      _buildRoomStatusSection() {
    return Consumer<
        RoomProvider>(
      builder:
          (context,
              roomProvider, _) {
        final rooms =
            roomProvider
                .rooms
                .take(3)
                .toList();

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Text(
              'Room Status',
              style: TextStyle(
                color: AppColors
                    .primaryText,
                fontSize: 16,
                fontWeight:
                    FontWeight
                        .w600,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            if (rooms
                .isEmpty)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .all(24),
                decoration:
                    BoxDecoration(
                      color: const Color(
                        0xFFF9FAFB,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color:
                            const Color(
                          0xFFE5E7EB,
                        ),
                        width: 1,
                      ),
                    ),
                child: Center(
                  child: Text(
                    'No rooms yet',
                    style:
                        TextStyle(
                          color: AppColors
                              .secondaryText,
                          fontSize: 14,
                        ),
                  ),
                ),
              )
            else
              ...rooms
                  .map(
                    (room) =>
                        _buildRoomCard(
                      room,
                    ),
                  )
                  .toList(),
          ],
        );
      },
    );
  }

  Widget _buildRoomCard(
    RoomModel room,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius
                .circular(10),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
          width: 1,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets
                .all(12),
        child: Row(
          children: [
            if (room
                .imageUrls
                .isNotEmpty)
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
                child:
                    Image.network(
                  room
                      .imageUrls
                      .first,
                  width: 48,
                  height: 48,
                  fit:
                      BoxFit
                          .cover,
                  errorBuilder:
                      (_, __, ___) =>
                          Container(
                        width:
                            48,
                        height:
                            48,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFE5E7EB,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .image,
                          size:
                              24,
                          color:
                              AppColors
                                  .borderColor,
                        ),
                      ),
                    ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                      color:
                          const Color(
                        0xFFE5E7EB,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                    ),
                child: const Icon(
                  Icons.image,
                  size: 24,
                  color: AppColors
                      .borderColor,
                ),
              ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    room.name,
                    style:
                        const TextStyle(
                          color: AppColors
                              .primaryText,
                          fontSize: 13,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons
                            .location_on_outlined,
                        size: 12,
                        color: AppColors
                            .secondaryText,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        room.city,
                        style:
                            TextStyle(
                              color: AppColors
                                  .secondaryText,
                              fontSize:
                                  11,
                            ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Icon(
                        Icons
                            .people_outline,
                        size: 12,
                        color: AppColors
                            .secondaryText,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        '${room.capacity} pax',
                        style:
                            TextStyle(
                              color: AppColors
                                  .secondaryText,
                              fontSize:
                                  11,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration:
                  BoxDecoration(
                color: room
                        .isAvailable
                    ? const Color(
                      0xFF16A34A,
                    ).withOpacity(
                      0.1,
                    )
                    : const Color(
                      0xFFDC2626,
                    ).withOpacity(
                      0.1,
                    ),
                borderRadius:
                    BorderRadius
                        .circular(
                  6,
                ),
              ),
              child: Text(
                room.isAvailable
                    ? 'Available'
                    : 'Unavailable',
                style: TextStyle(
                  color: room
                          .isAvailable
                      ? const Color(
                        0xFF16A34A,
                      )
                      : const Color(
                        0xFFDC2626,
                      ),
                  fontSize: 11,
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
