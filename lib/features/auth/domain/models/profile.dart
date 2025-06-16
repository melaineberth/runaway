// lib/features/auth/domain/models/profile.dart

class Profile {
  final String id;
  final String? username;
  final String? avatarUrl;
  final String? fullName;
  final DateTime? updatedAt;
  final String email;

  Profile({
    required this.id,
    this.username,
    required this.email,
    this.avatarUrl,
    this.fullName,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    username: json['username'] as String?,
    email: json['email'] as String,
    avatarUrl: json['avatar_url'] as String?,
    fullName: json['full_name'] as String?,
    updatedAt: json['updated_at'] != null 
        ? DateTime.tryParse(json['updated_at'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'avatar_url': avatarUrl,
    'full_name': fullName,
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Méthode helper pour vérifier si le profil est complet
  bool get isComplete {
    return username != null && 
           username!.isNotEmpty && 
           fullName != null && 
           fullName!.isNotEmpty;
  }

  /// Méthode helper pour obtenir le nom d'affichage
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    if (username != null && username!.isNotEmpty) {
      return '@$username';
    }
    return email;
  }

  /// Méthode helper pour obtenir les initiales
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    
    return email[0].toUpperCase();
  }

  /// Méthode pour créer une copie avec des champs modifiés
  Profile copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? fullName,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Méthode pour vérifier si le profil a une photo
  bool get hasAvatar {
    return avatarUrl != null && avatarUrl!.isNotEmpty;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.id == id &&
        other.username == username &&
        other.email == email &&
        other.avatarUrl == avatarUrl &&
        other.fullName == fullName &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      username,
      email,
      avatarUrl,
      fullName,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Profile(id: $id, username: $username, email: $email, fullName: $fullName, hasAvatar: $hasAvatar)';
  }
}