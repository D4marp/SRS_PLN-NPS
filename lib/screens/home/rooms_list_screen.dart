import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/room_model.dart';
import '../../providers/room_provider.dart';
import '../../utils/app_theme.dart';
import '../../core/gen/assets.gen.dart';
import '../room/room_details_screen.dart';

class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key});

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RoomModel> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRooms();
    });
  }

  Future<void> _loadRooms() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.loadRooms();

    if (mounted) {
      setState(() {
        _rooms = roomProvider.allRooms;
        if (_rooms.isNotEmpty) {
          _tabController = TabController(length: _rooms.length, vsync: this);
        }
        _isLoading = false;
      });
    }
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
          title: const Text('Select a Room'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryText),
          ),
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select a Room'),
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
                  backgroundColor: AppColors.primaryText,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Image - Tab Screen
          Positioned.fill(
            child: Image(
              image: Assets.images.bgBooking.provider(),
              fit: BoxFit.cover,
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.015,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: MediaQuery.of(context).size.width * 0.02,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Select a Room',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.019,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: MediaQuery.of(context).size.width * 0.02,
                        ),
                        onPressed: _loadRooms,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                
                // Tabs
                Container(
                  height: MediaQuery.of(context).size.height * 0.09,
                  margin: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.015,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabAlignment: TabAlignment.start,
                    tabs: _rooms.map((room) {
                      return Tab(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.015,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getRoomIcon(room.roomClass),
                                size: MediaQuery.of(context).size.width * 0.016,
                              ),
                              SizedBox(width: MediaQuery.of(context).size.width * 0.006),
                              Text(
                                room.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: MediaQuery.of(context).size.width * 0.013,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _rooms.map((room) {
                      return _buildRoomCard(room);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(RoomModel room) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive padding and sizing
    final horizontalPadding = screenWidth * 0.04;
    final verticalPadding = screenHeight * 0.05;
    final cardPadding = screenWidth * 0.025;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        children: [
          // Left side - Room Info
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: room.isAvailable
                      ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                      : [const Color(0xFF616161), const Color(0xFF424242)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Room Icon & Name
                    Row(
                      children: [
                        Icon(
                          _getRoomIcon(room.roomClass),
                          color: Colors.white,
                          size: screenWidth * 0.04,
                        ),
                        SizedBox(width: screenWidth * 0.012),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                room.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: screenWidth * 0.028,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                room.roomClass,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: screenWidth * 0.014,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Details Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            Icons.location_on,
                            '${room.location}, ${room.city}',
                            screenWidth,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.012),
                        Expanded(
                          child: _buildInfoItem(
                            Icons.people,
                            '${room.maxGuests} Guests',
                            screenWidth,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.012),
                        Expanded(
                          child: _buildInfoItem(
                            room.hasAC ? Icons.ac_unit : Icons.wind_power,
                            room.hasAC ? 'AC' : 'Fan',
                            screenWidth,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: screenHeight * 0.03),
                    
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.016,
                        vertical: screenHeight * 0.02,
                      ),
                      decoration: BoxDecoration(
                        color: room.isAvailable
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            room.isAvailable ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: screenWidth * 0.02,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Flexible(
                            child: Text(
                              room.isAvailable ? 'Available Now' : 'Currently Booked',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: screenWidth * 0.014,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(width: screenWidth * 0.025),
          
          // Right side - Action Button
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: screenWidth * 0.3),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailsScreen(
                          room: room,
                          isKioskMode: true,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryText,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enter Booking',
                        style: TextStyle(
                          fontSize: screenWidth * 0.019,
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      Icon(Icons.arrow_forward, size: screenWidth * 0.022),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.01),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: screenWidth * 0.016),
          SizedBox(width: screenWidth * 0.006),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth * 0.011,
                fontWeight: FontWeight.w600,
                fontFamily: 'Plus Jakarta Sans',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
