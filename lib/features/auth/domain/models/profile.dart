class Profile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String email;

  Profile({
    required this.id,
    this.username,
    required this.email,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'avatar_url': avatarUrl,
  };
}
