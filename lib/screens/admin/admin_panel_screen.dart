import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/room_provider.dart';
import '../../models/room_model.dart';
import '../../utils/app_theme.dart';
import 'add_edit_room_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_users_screen.dart';
import 'admin_dashboard_screen.dart';
import 'booking_calendar_screen.dart';

/// Professional admin panel with industrial design
/// Admin → [Dashboard] [Calendar] [Rooms] [Bookings]
/// Superadmin → [Dashboard] [Calendar] [Rooms] [Bookings] [Users]
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _isSuperAdmin = auth.userModel?.isSuperAdmin == true;
    _tabController = TabController(
      length: _isSuperAdmin ? 5 : 4,
      vsync: this,
    );
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadStats();
      Provider.of<AdminProvider>(context, listen: false).loadBookings();
      Provider.of<RoomProvider>(context, listen: false).fetchRooms();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.userModel?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: const Center(
          child: Text('You do not have admin privileges'),
        ),
      );
    }

    return Consumer<AdminProvider>(
      builder: (context, adminProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.creamBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: const Text(
              'Admin Panel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            iconTheme: const IconThemeData(
              color: AppColors.primaryText,
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryRed,
              indicatorWeight: 2.5,
              labelColor: AppColors.primaryRed,
              unselectedLabelColor: AppColors.secondaryText,
              isScrollable: false,
              tabs: [
                const Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 20),
                  text: 'Dashboard',
                ),
                const Tab(
                  icon: Icon(Icons.calendar_month, size: 20),
                  text: 'Calendar',
                ),
                const Tab(
                  icon: Icon(Icons.meeting_room_outlined, size: 20),
                  text: 'Rooms',
                ),
                Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_note_outlined, size: 20),
                        const SizedBox(width: 4),
                        const Text('Bookings'),
                        if (adminProvider.pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              adminProvider.pendingCount > 99
                                  ? '99+'
                                  : '${adminProvider.pendingCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_isSuperAdmin)
                  const Tab(
                    icon: Icon(Icons.people_outline, size: 20),
                    text: 'Users',
                  ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              const AdminDashboardScreen(),
              const BookingCalendarScreen(),
              const _RoomsTabContent(),
              const AdminBookingsScreen(),
              if (_isSuperAdmin) const AdminUsersScreen(),
            ],
          ),
          floatingActionButton:
              _tabController.index == 2
                  ? Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors
                                .primaryRed
                                .withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        onPressed: () =>
                            Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddEditRoomScreen(),
                          ),
                        ),
                        backgroundColor:
                            AppColors.primaryRed,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(14),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
        );
      },
    );
  }
}

// ─── Rooms Tab ────────────────────────────────────────────────────────────────

class _RoomsTabContent extends StatelessWidget {
  const _RoomsTabContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, _) {
        if (roomProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primaryRed),
            ),
          );
        }

        if (roomProvider.rooms.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 64,
                    color: AppColors.primaryRed
                        .withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No rooms yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a new room',
                    style: TextStyle(
                      color:
                          AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: () =>
              roomProvider.fetchRooms(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roomProvider
                .rooms.length,
            itemBuilder:
                (context, index) {
              return _RoomCard(
                room: roomProvider
                    .rooms[index],
              );
            },
          ),
        );
      },
    );
  }
}

class _RoomCard
    extends StatelessWidget {
  const _RoomCard(
      {required this.room});

  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final roomProvider =
        Provider.of<RoomProvider>(
      context,
      listen: false,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
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
            CrossAxisAlignment
                .start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius
                .vertical(
              top: Radius.circular(
                12,
              ),
            ),
            child: room
                    .imageUrls
                    .isNotEmpty
                ? Image.network(
                    room.imageUrls
                        .first,
                    height: 160,
                    width:
                        double
                            .infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            _placeholder(),
                  )
                : _placeholder(),
          ),

          Padding(
            padding:
                const EdgeInsets
                    .all(14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style:
                            const TextStyle(
                              color: AppColors
                                  .primaryText,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              fontSize: 16,
                            ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            8,
                        vertical: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .primaryRed
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
                          color: AppColors
                              .primaryRed,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        room.roomClass,
                        style:
                            const TextStyle(
                              color: AppColors
                                  .primaryRed,
                              fontSize:
                                  11,
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
                Row(
                  children: [
                    Icon(
                      Icons
                          .location_on_outlined,
                      size: 14,
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
                            fontSize: 13,
                          ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.people,
                      size: 14,
                      color: AppColors
                          .secondaryText,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      room
                          .capacityInfo,
                      style:
                          TextStyle(
                            color: AppColors
                                .secondaryText,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          ElevatedButton
                              .icon(
                        onPressed: () =>
                            Navigator
                                .push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        AddEditRoomScreen(
                                  room:
                                      room,
                                ),
                              ),
                            ),
                        icon: const Icon(
                          Icons
                              .edit,
                          size: 16,
                          color:
                              Colors
                                  .white,
                        ),
                        label:
                            const Text(
                          'Edit',
                          style:
                              TextStyle(
                                color:
                                    Colors
                                        .white,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                                  AppColors
                                      .primaryRed,
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical:
                                    10,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          OutlinedButton
                              .icon(
                        onPressed: () =>
                            _confirmDelete(
                              context,
                              room,
                              roomProvider,
                            ),
                        icon: const Icon(
                          Icons
                              .delete,
                          size: 16,
                          color: Colors
                              .red,
                        ),
                        label:
                            const Text(
                          'Delete',
                          style:
                              TextStyle(
                                color:
                                    Colors
                                        .red,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical:
                                    10,
                              ),
                              side:
                                  const BorderSide(
                                color:
                                    Colors
                                        .red,
                                width:
                                    1.5,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 160,
      width:
          double.infinity,
      color: const Color(
        0xFFF3F4F6,
      ),
      child: Icon(
        Icons.image,
        size: 50,
        color: AppColors
            .borderColor
            .withOpacity(0.3),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    RoomModel room,
    RoomProvider roomProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
        title: const Text(
          'Delete Room',
        ),
        content:
            Text(
          'Delete "${room.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              ctx,
            ),
            child: const Text(
              'Cancel',
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(
                ctx,
              );
              try {
                await roomProvider
                    .deleteRoom(
                  room.id,
                );
                if (context
                    .mounted) {
                  ScaffoldMessenger
                      .of(
                    context,
                  )
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Room deleted',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context
                    .mounted) {
                  ScaffoldMessenger
                      .of(
                    context,
                  )
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error: $e',
                      ),
                    ),
                  );
                }
              }
            },
            style:
                TextButton
                    .styleFrom(
              foregroundColor:
                  Colors.red,
            ),
            child: const Text(
              'Delete',
            ),
          ),
        ],
      ),
    );
  }
}
