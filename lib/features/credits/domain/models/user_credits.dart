import 'package:equatable/equatable.dart';

class UserCredits extends Equatable {
  final String id;
  final String userId;
  final int availableCredits;
  final int totalCreditsPurchased;
  final int totalCreditsUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserCredits({
    required this.id,
    required this.userId,
    required this.availableCredits,
    required this.totalCreditsPurchased,
    required this.totalCreditsUsed,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasCredits => availableCredits > 0;
  bool get canGenerate => hasCredits;

  factory UserCredits.fromJson(Map<String, dynamic> json) {
    return UserCredits(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      availableCredits: json['available_credits'] as int,
      totalCreditsPurchased: json['total_credits_purchased'] as int,
      totalCreditsUsed: json['total_credits_used'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'available_credits': availableCredits,
      'total_credits_purchased': totalCreditsPurchased,
      'total_credits_used': totalCreditsUsed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserCredits copyWith({
    String? id,
    String? userId,
    int? availableCredits,
    int? totalCreditsPurchased,
    int? totalCreditsUsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserCredits(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      availableCredits: availableCredits ?? this.availableCredits,
      totalCreditsPurchased: totalCreditsPurchased ?? this.totalCreditsPurchased,
      totalCreditsUsed: totalCreditsUsed ?? this.totalCreditsUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    availableCredits,
    totalCreditsPurchased,
    totalCreditsUsed,
    createdAt,
    updatedAt,
  ];
}
