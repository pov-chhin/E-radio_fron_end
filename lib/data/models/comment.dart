class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.userName,
    required this.isMine,
    this.userAvatarUrl,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String userName;
  final bool isMine;
  final String? userAvatarUrl;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return Comment(
      id: json['id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: user['name'] as String,
      userAvatarUrl: user['avatar_url'] as String?,
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}
