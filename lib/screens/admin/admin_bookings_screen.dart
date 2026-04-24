import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';

/// Booking approval queue shown in the Bookings tab of AdminPanelScreen.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statusFilters = [null, 'pending', 'confirmed', 'rejected'];
  static const _tabLabels = ['All', 'Pending', 'Confirmed', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadBookings();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    context.read<AdminProvider>().loadBookings(
          status: _statusFilters[_tabController.index],
        );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter tabs
        Container(
          color: const Color(0xCC170F0F),
          child: Consumer<AdminProvider>(
            builder: (context, adminProvider, _) {
              final pendingCount = adminProvider.bookings
                  .where((b) => b.status == BookingStatus.pending)
                  .length;
              return TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primaryRed,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'All'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pending'),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Confirmed'),
                  const Tab(text: 'Rejected'),
                ],
              );
            },
          ),
        ),

        // Content
        Expanded(
          child: Consumer<AdminProvider>(
            builder: (context, adminProvider, _) {
              if (adminProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryRed),
                  ),
                );
              }

              if (adminProvider.bookings.isEmpty) {
                return _buildEmptyState(_tabLabels[_tabController.index]);
              }

              return RefreshIndicator(
                color: AppColors.primaryRed,
                onRefresh: () => adminProvider.loadBookings(
                  status: _statusFilters[_tabController.index],
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: adminProvider.bookings.length,
                  itemBuilder: (context, index) {
                    return _buildBookingCard(
                        adminProvider.bookings[index], adminProvider);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xBF170F0F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFAF0406), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy,
                size: 64, color: AppColors.primaryRed.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No $label Bookings',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking, AdminProvider adminProvider) {
    final date = booking.bookingDate.toLocal();
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

    final statusColor = _statusColor(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC170F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A1A1A), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: room name + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.roomName ?? 'Unknown Room',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(booking.status, statusColor),
              ],
            ),
            const SizedBox(height: 10),

            // Date + time
            _infoRow(Icons.calendar_today, '$formattedDate  •  ${booking.checkInTime} - ${booking.checkOutTime}'),
            const SizedBox(height: 4),

            // User
            _infoRow(Icons.person_outline, booking.userName ?? booking.userId),
            const SizedBox(height: 4),

            // Guests + location
            _infoRow(Icons.people_outline, '${booking.numberOfGuests} guest(s)  •  ${booking.roomLocation ?? '-'}'),

            // Purpose
            if (booking.purpose != null && booking.purpose!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.notes, booking.purpose!),
            ],

            // Rejection reason
            if (booking.status == BookingStatus.rejected &&
                booking.rejectionReason != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${booking.rejectionReason}',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            if (booking.status == BookingStatus.pending ||
                booking.status == BookingStatus.confirmed) ...[
              const SizedBox(height: 14),
              _buildActionButtons(booking, adminProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(BookingStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking, AdminProvider admin) {
    if (booking.status == BookingStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approve(booking.id, admin),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(booking.id, admin),
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              label: const Text('Reject',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    // Confirmed
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _complete(booking.id, admin),
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _cancel(booking.id, admin),
            icon: const Icon(Icons.cancel_outlined,
                size: 16, color: Colors.orange),
            label: const Text('Cancel',
                style: TextStyle(color: Colors.orange)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(String id, AdminProvider admin) async {
    final ok = await admin.approveBooking(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Booking approved' : admin.errorMessage ?? 'Error'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _complete(String id, AdminProvider admin) async {
    final ok = await admin.completeBooking(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Marked as completed' : admin.errorMessage ?? 'Error'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _cancel(String id, AdminProvider admin) async {
    final ok = await admin.cancelBooking(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Booking cancelled' : admin.errorMessage ?? 'Error'),
        backgroundColor: ok ? Colors.orange : Colors.red,
      ));
    }
  }

  void _showRejectDialog(String id, AdminProvider admin) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1010),
        title: const Text('Reject Booking',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter rejection reason (required)',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A1212),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: AppColors.primaryRed.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: AppColors.primaryRed.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primaryRed, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = ctrl.text.trim();
              if (reason.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Reason must be at least 5 characters'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.pop(ctx);
              final ok = await admin.rejectBooking(id, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Booking rejected'
                      : admin.errorMessage ?? 'Error'),
                  backgroundColor: ok ? Colors.orange : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed),
            child: const Text('Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _statusLabel(BookingStatus s) {
    return switch (s) {
      BookingStatus.pending => 'Pending',
      BookingStatus.confirmed => 'Confirmed',
      BookingStatus.rejected => 'Rejected',
      BookingStatus.cancelled => 'Cancelled',
      BookingStatus.completed => 'Completed',
    };
  }

  Color _statusColor(BookingStatus s) {
    return switch (s) {
      BookingStatus.pending => Colors.amber,
      BookingStatus.confirmed => Colors.green,
      BookingStatus.rejected => Colors.red,
      BookingStatus.cancelled => Colors.orange,
      BookingStatus.completed => const Color(0xFF1E88E5),
    };
  }
}
