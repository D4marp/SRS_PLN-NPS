// Role hierarchy: superadmin > admin > booking > user
enum UserRole { user, booking, admin, superadmin }

extension UserRoleX on UserRole {
  /// isAdmin berlaku untuk admin DAN superadmin
  bool get isAdmin => this == UserRole.admin || this == UserRole.superadmin;
  bool get isSuperAdmin => this == UserRole.superadmin;

  String get value {
    switch (this) {
      case UserRole.superadmin:
        return 'superadmin';
      case UserRole.admin:
        return 'admin';
      case UserRole.booking:
        return 'booking';
      case UserRole.user:
        return 'user';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'superadmin':
        return UserRole.superadmin;
      case 'admin':
        return UserRole.admin;
      case 'booking':
        return UserRole.booking;
      default:
        return UserRole.user;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final String? city;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final UserRole role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.city,
    required this.createdAt,
    this.updatedAt,
    this.role = UserRole.user,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      city: json['city'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'])
          : null,
      role: UserRoleX.fromString(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'city': city,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'role': role.value,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImage,
    String? city,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
    );
  }

  /// isAdmin berlaku untuk admin DAN superadmin
  bool get isAdmin => role.isAdmin;
  bool get isSuperAdmin => role.isSuperAdmin;
}
