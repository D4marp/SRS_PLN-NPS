import 'package:bookify_rooms/core/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../models/booking_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/booking_card.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Start listening to real-time booking updates (Stream-based)
    // No timer needed - Stream auto-updates in real-time! 🔥
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  void _loadBookings() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);

    if (authProvider.user != null) {
      debugPrint('🔥 Loading user bookings with real-time stream for user: ${authProvider.user!.uid}');
      bookingProvider.loadUserBookings(authProvider.user!.uid);
    }
  }

  void _retryLoadBookings() {
    final bookingProvider =
        Provider.of<BookingProvider>(context, listen: false);
    bookingProvider.clearError();
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildCustomTab(String label, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFFEC0303) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 16,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full background image
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/My Bookings.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Content
        Scaffold(
          backgroundColor: Colors.transparent,
            appBar: AppBar(
            title: const Center(
              child: Text(
              'My Bookings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
              ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, child) {
          if (bookingProvider.isLoading && bookingProvider.userBookings.isEmpty) {
            return _buildShimmerLoading();
          }

          if (bookingProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.errorRed.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Oops! Something went wrong',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.errorRed,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      bookingProvider.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Retry button
                  ElevatedButton.icon(
                    onPressed: _retryLoadBookings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Info about composite index
                  if (bookingProvider.errorMessage!.contains('failed-precondition') ||
                      bookingProvider.errorMessage!.contains('composite index'))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firebase Index Required',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This app requires a Firestore composite index. Click the link in the error message above to create it in Firebase Console.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Custom Tab Bar
                // Custom Tab Bar with filter icon at right
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
                  child: Row(
                    children: [
                      // Tabs at the left
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(scale: 0.85, child: _buildCustomTab('All', 0)),
                          Transform.scale(scale: 0.85, child: _buildCustomTab('Upcoming', 1)),
                          Transform.scale(scale: 0.85, child: _buildCustomTab('Past', 2)),
                        ],
                      ),
                      const Spacer(),
                      // Filter icon at the right corner
                      GestureDetector(
                        onTap: () {
                          // Handle filter tap if needed
                        },
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Assets.images.filter.svg(width: 36, height: 36),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                  _buildBookingsList(bookingProvider.userBookings, 'all'),
                  _buildBookingsList(bookingProvider.upcomingBookings, 'upcoming'),
                  _buildBookingsList(bookingProvider.pastBookings, 'past'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
        ),
      ],
    );
  }

  Widget _buildBookingsList(List<BookingModel> bookings, String type) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(type),
              size: 64,
              color: AppColors.lightText,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _getEmptyStateTitle(type),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _getEmptyStateSubtitle(type),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.lightText,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final bookingProvider =
            Provider.of<BookingProvider>(context, listen: false);

        if (authProvider.user != null) {
          await bookingProvider.refreshBookings(authProvider.user!.uid);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: BookingCard(
              booking: booking,
              onTap: () {
                // Navigate to booking details
                _showBookingDetails(booking);
              },
              onCancel:
                  booking.canBeCancelled ? () => _cancelBooking(booking) : null,
            ),
          );
        },
      ),
    );
  }

  IconData _getEmptyStateIcon(String type) {
    switch (type) {
      case 'upcoming':
        return Icons.upcoming;
      case 'past':
        return Icons.history;
      default:
        return Icons.book_outlined;
    }
  }

  String _getEmptyStateTitle(String type) {
    switch (type) {
      case 'upcoming':
        return 'No Upcoming Bookings';
      case 'past':
        return 'No Past Bookings';
      default:
        return 'No Bookings Yet';
    }
  }

  String _getEmptyStateSubtitle(String type) {
    switch (type) {
      case 'upcoming':
        return 'You don\'t have any upcoming reservations.\nStart planning your next getaway!';
      case 'past':
        return 'You haven\'t completed any stays yet.\nYour booking history will appear here.';
      default:
        return 'You haven\'t made any reservations yet.\nExplore amazing rooms and book your perfect stay!';
    }
  }

  void _showBookingDetails(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingDetailsSheet(booking: booking),
    );
  }

  void _cancelBooking(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final bookingProvider =
                  Provider.of<BookingProvider>(context, listen: false);
              final success = await bookingProvider.cancelBooking(booking.id);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking cancelled successfully'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(bookingProvider.errorMessage ??
                        'Failed to cancel booking'),
                    backgroundColor: AppColors.errorRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Custom tabs shimmer
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ShimmerBox(
                        width: 80,
                        height: 36,
                        borderRadius: 6,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _ShimmerBox(width: 36, height: 36, borderRadius: 8),
              ],
            ),
          ),
          // Booking cards shimmer
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildShimmerBookingCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBookingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image shimmer
          _ShimmerBox(
            width: 100,
            height: 90,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          // Content shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 18, borderRadius: 4),
                const SizedBox(height: 8),
                _ShimmerBox(width: 150, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ShimmerBox(width: 16, height: 16, borderRadius: 4),
                    const SizedBox(width: 4),
                    _ShimmerBox(width: 100, height: 13, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _ShimmerBox(width: 16, height: 16, borderRadius: 4),
                    const SizedBox(width: 4),
                    _ShimmerBox(width: 120, height: 13, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 0,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingDetailsSheet extends StatelessWidget {
  final BookingModel booking;

  const _BookingDetailsSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'Booking Details',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    // Booking ID and Status
                    _buildDetailRow('Booking ID', booking.id),
                    _buildDetailRow('Status', booking.statusDisplayName),

                    const Divider(height: AppSpacing.xl),

                    // Room Details
                    if (booking.roomName != null) ...[
                      _buildDetailRow('Room', booking.roomName!),
                      if (booking.roomLocation != null)
                        _buildDetailRow('Location', booking.roomLocation!),
                    ],

                    const Divider(height: AppSpacing.xl),

                    // Booking Details
                    _buildDetailRow(
                        'Date', _formatDate(booking.bookingDate)),
                    _buildDetailRow(
                        'Start Time', booking.checkInTime),
                    _buildDetailRow(
                        'End Time', booking.checkOutTime),
                    _buildDetailRow(
                        'Duration', _calculateDuration(booking.checkInTime, booking.checkOutTime)),
                    _buildDetailRow('Number of Guests', '${booking.numberOfGuests} ${booking.numberOfGuests == 1 ? "person" : "people"}'),
                    if (booking.purpose != null && booking.purpose!.isNotEmpty)
                      _buildDetailRow('Purpose', booking.purpose!),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _calculateDuration(String startTime, String endTime) {
    try {
      final start = TimeOfDay(
        hour: int.parse(startTime.split(':')[0]),
        minute: int.parse(startTime.split(':')[1]),
      );
      final end = TimeOfDay(
        hour: int.parse(endTime.split(':')[0]),
        minute: int.parse(endTime.split(':')[1]),
      );
      
      int startMinutes = start.hour * 60 + start.minute;
      int endMinutes = end.hour * 60 + end.minute;
      
      // Handle case where end time is next day
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }
      
      int durationMinutes = endMinutes - startMinutes;
      int hours = durationMinutes ~/ 60;
      int minutes = durationMinutes % 60;
      
      if (hours > 0 && minutes > 0) {
        return '$hours hour${hours > 1 ? "s" : ""} $minutes min${minutes > 1 ? "s" : ""}';
      } else if (hours > 0) {
        return '$hours hour${hours > 1 ? "s" : ""}';
      } else {
        return '$minutes minute${minutes > 1 ? "s" : ""}';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}
