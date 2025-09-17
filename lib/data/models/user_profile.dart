class UserProfile {
  final String id;
  final String? email;
  final String? phone;
  final String? googleId;
  final String? fullName;
  final String? avatarUrl;
  final double reputationScore;
  final int totalTrips;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.email,
    this.phone,
    this.googleId,
    this.fullName,
    this.avatarUrl,
    required this.reputationScore,
    required this.totalTrips,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      googleId: json['google_id'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      reputationScore: (json['reputation_score'] ?? 5.0).toDouble(),
      totalTrips: json['total_trips'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'google_id': googleId,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'reputation_score': reputationScore,
      'total_trips': totalTrips,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
