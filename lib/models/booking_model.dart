enum BookingStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed,
}

class BookingModel {
  final String id;
  final String userId;
  final String roomId;
  final DateTime bookingDate; // Tanggal booking (same day booking only)
  final String checkInTime;  // Format: "HH:mm" e.g., "14:00"
  final String checkOutTime; // Format: "HH:mm" e.g., "11:00"
  final int numberOfGuests;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? purpose; // Purpose of booking (meeting, class, event, etc.)

  // Approval fields
  final String? rejectionReason;
  final String? approvedBy; // userId of admin who approved/rejected
  final DateTime? approvedAt;

  // Additional room details for display
  final String? roomName;
  final String? roomLocation;
  final String? roomImageUrl;

  // User details for display
  final String? userName;
  final String? userEmail;

  BookingModel({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.bookingDate,
    required this.checkInTime,
    required this.checkOutTime,
    required this.numberOfGuests,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.purpose,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    this.roomName,
    this.roomLocation,
    this.roomImageUrl,
    this.userName,
    this.userEmail,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      roomId: json['roomId'] ?? '',
      bookingDate:
          DateTime.fromMillisecondsSinceEpoch(json['bookingDate'] ?? 0),
      checkInTime: json['checkInTime'] ?? '08:00',
      checkOutTime: json['checkOutTime'] ?? '17:00',
      numberOfGuests: json['numberOfGuests'] ?? 1,
      status: BookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BookingStatus.pending,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      purpose: json['purpose'],
      rejectionReason: json['rejectionReason'],
      approvedBy: json['approvedBy'],
      approvedAt: json['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['approvedAt'])
          : null,
      roomName: json['roomName'],
      roomLocation: json['roomLocation'],
      roomImageUrl: json['roomImageUrl'],
      userName: json['userName'],
      userEmail: json['userEmail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'roomId': roomId,
      'bookingDate': bookingDate.millisecondsSinceEpoch,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'numberOfGuests': numberOfGuests,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'purpose': purpose,
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'roomName': roomName,
      'roomLocation': roomLocation,
      'roomImageUrl': roomImageUrl,
      'userName': userName,
      'userEmail': userEmail,
    };
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? roomId,
    DateTime? bookingDate,
    String? checkInTime,
    String? checkOutTime,
    int? numberOfGuests,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? purpose,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
    String? roomName,
    String? roomLocation,
    String? roomImageUrl,
    String? userName,
    String? userEmail,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      bookingDate: bookingDate ?? this.bookingDate,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      purpose: purpose ?? this.purpose,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      roomName: roomName ?? this.roomName,
      roomLocation: roomLocation ?? this.roomLocation,
      roomImageUrl: roomImageUrl ?? this.roomImageUrl,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  // Computed properties
  String get statusDisplayName {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }

  bool get canBeCancelled {
    return status == BookingStatus.pending || status == BookingStatus.confirmed;
  }

  bool get isActive {
    return status == BookingStatus.confirmed;
  }

  String get formattedDate {
    return '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}';
  }

  String get formattedTimeRange {
    return '$checkInTime - $checkOutTime';
  }
}
