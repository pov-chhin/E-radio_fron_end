class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.joinedAt,
    this.address,
    this.phoneNumber,
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime joinedAt;
  final String? address;
  final String? phoneNumber;
  final String? avatarUrl;

  String get name => '$firstName $lastName'.trim();

  /// Share of the profile's fields that are filled in, as a whole percent —
  /// drives the "90% complete" prompt on the Account screen.
  int get completionPercent {
    final filled = [
      firstName,
      lastName,
      email,
      phoneNumber,
      address,
      avatarUrl,
    ].where((value) => value != null && value.trim().isNotEmpty).length;
    return (filled * 100 / 6).round();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    email: json['email'] as String,
    joinedAt: DateTime.parse(json['joined_at'] as String),
    address: json['address'] as String?,
    phoneNumber: json['phone_number'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'joined_at': joinedAt.toIso8601String(),
    'address': address,
    'phone_number': phoneNumber,
    'avatar_url': avatarUrl,
  };
}
