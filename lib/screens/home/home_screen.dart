import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../profile/profile_screen.dart';
import '../booking/booking_history_screen.dart';
import '../booking/user_booking_screen.dart';
import 'rooms_list_screen.dart';
import '../../core/gen/assets.gen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  int _selectedIndex = 0;
  String _userLocation = 'Loading...';
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      roomProvider.loadRooms();
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _userLocation = 'Permission denied';
              _locationLoading = false;
            });
          }
          return;
        }
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.locality ?? place.administrativeArea ?? 'Unknown';
        final country = place.country ?? 'Indonesia';

        setState(() {
          _userLocation = '$city, $country';
          _locationLoading = false;
        });

        // Optionally update user location in Firestore
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.userModel != null) {
          authProvider.updateUserLocation(city);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _userLocation = 'Unable to get location';
          _locationLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show RoomsListScreen for Booking role
        if (authProvider.userModel?.role == UserRole.booking) {
          return const RoomsListScreen();
        }

        // Default UI for User and Admin roles
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(),
              const BookingHistoryScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
          resizeToAvoidBottomInset: false,
          extendBody: true,
        );
      },
    );
  }

  Widget _buildHomeTab() {
    return Stack(
      children: [
        // Full background image
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: Assets.images.homeBg.provider(),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final userName =
                                      authProvider.userModel?.name ??
                                          authProvider.userModel?.email
                                              ?.split('@')
                                              .first ??
                                          'User';
                                  return Text(
                                    'Hello, $userName!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Current location',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final displayLocation = _locationLoading
                                      ? 'Getting location...'
                                      : _userLocation;
                                  return Row(
                                    children: [
                                      Assets.icon.location.svg(
                                        width: 18,
                                        height: 18,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          displayLocation,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Notification button
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Assets.icon.notif.svg(
                              width: 24,
                              height: 24,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFE74C3C),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: CustomSearchField(
                      controller: _searchController,
                      hintText: 'Search room, type, location...',
                      onChanged: (query) {
                        final roomProvider = Provider.of<RoomProvider>(
                          context,
                          listen: false,
                        );
                        roomProvider.searchRooms(query);
                      },
                      onClear: () {
                        final roomProvider = Provider.of<RoomProvider>(
                          context,
                          listen: false,
                        );
                        roomProvider.searchRooms('');
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Category section
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      'Category',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category chips
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      children: [
                        _buildCategoryChip(
                          'Meeting Room',
                          Assets.icon.conference,
                          isActive: true,
                        ),
                        const SizedBox(width: 12),
                        _buildCategoryChip(
                          'Conference Room',
                          Assets.icon.conference,
                          isActive: false,
                        ),
                        const SizedBox(width: 12),
                        _buildCategoryChip(
                          'Cinema Room',
                          Assets.icon.cinemaRoom,
                          isActive: false,
                        ),
                        const SizedBox(width: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Room cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Consumer<RoomProvider>(
                      builder: (context, roomProvider, child) {
                        if (roomProvider.isLoading) {
                          return Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          );
                        }

                        if (roomProvider.rooms.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                'No rooms available',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: roomProvider.rooms
                              .map((room) => Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: _buildRoomCard(room),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, SvgGenImage icon,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: isActive ? const Color(0xFFEC0303) : Colors.white,
        shape: RoundedRectangleBorder(
          side: isActive
              ? BorderSide.none
              : const BorderSide(
                  width: 1,
                  color: Color(0xFFBBBBBB),
                ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon.svg(
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isActive ? Colors.white : Colors.black,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontSize: 16,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w500,
              height: 1.50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room image with status badge
            Stack(
              children: [
                // Room image
                room.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: room.imageUrls.first,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          height: 200,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          height: 200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        height: 200,
                        width: double.infinity,
                        child: const Icon(Icons.image_not_supported),
                      ),
                // Available badge
                Positioned(
                  left: 16,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0xFF04B04C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Room info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room name
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Guests
                  Row(
                    children: [
                      Assets.icon.guests.svg(
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF999999),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Up to ${room.maxGuests} guests',
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 13,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Amenities
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildAmenityChips(room),
                  ),
                  const SizedBox(height: 16),
                  // Book now button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC0303),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                UserBookingScreen(room: room),
                          ),
                        );
                      },
                      child: const Text(
                        'Book now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAmenityChips(RoomModel room) {
    final amenities = [
      'AC',
      'Projector',
      'Interactive Panel',
    ];

    return amenities
        .map((amenity) => _buildAmenityChip(amenity, Assets.icon.conference))
        .toList();
  }

  Widget _buildAmenityChip(String label, SvgGenImage icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: const Color(0xFFD9D9D9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(75),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon.svg(
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Colors.black,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              height: 1.50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      width: double.infinity,
      decoration: const ShapeDecoration(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 2,
            color: Color(0xFFFF0606),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 12, 0, MediaQuery.of(context).padding.bottom + 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home Tab
            _buildNavItem(
              index: 0,
              icon: Assets.icon.home,
              label: 'Home',
              isCircular: true,
            ),
            // Bookings Tab
            _buildNavItem(
              index: 1,
              icon: Assets.icon.bookings,
              label: 'Bookings',
              isCircular: false,
            ),
            // Profile Tab
            _buildNavItem(
              index: 2,
              icon: Assets.icon.profile,
              label: 'Profile',
              isCircular: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required SvgGenImage icon,
    required String label,
    required bool isCircular,
  }) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onBottomNavTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCircular)
            Container(
              width: 48,
              height: 48,
              decoration: ShapeDecoration(
                color: isSelected
                    ? const Color(0xFFEC0303)
                    : Colors.transparent,
                shape: const OvalBorder(),
              ),
              child: Center(
                child: icon.svg(
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: icon.svg(
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isSelected ? const Color(0xFFFF0606) : Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}