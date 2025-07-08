import 'package:equatable/equatable.dart';

class CreditPlan extends Equatable {
  final String id;
  final String name;
  final int credits;
  final double price;
  final String currency;
  final double? bonusPercentage;
  final bool isPopular;
  final List<String> features;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditPlan({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    required this.currency,
    this.bonusPercentage,
    this.isPopular = false,
    this.features = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get pricePerCredit => price / credits;
  
  String get formattedPrice => '${price.toStringAsFixed(2)} $currency';
  
  int get totalCreditsWithBonus => bonusPercentage != null 
      ? (credits * (1 + bonusPercentage! / 100)).round()
      : credits;

  String get bonusText => bonusPercentage != null && bonusPercentage! > 0
      ? '+${bonusPercentage!.toStringAsFixed(0)}% bonus'
      : '';

  factory CreditPlan.fromJson(Map<String, dynamic> json) {
    return CreditPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      credits: json['credits'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      bonusPercentage: json['bonus_percentage'] != null 
          ? (json['bonus_percentage'] as num).toDouble() 
          : null,
      isPopular: json['is_popular'] as bool? ?? false,
      features: (json['features'] as List<dynamic>?)?.cast<String>() ?? [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'credits': credits,
      'price': price,
      'currency': currency,
      'bonus_percentage': bonusPercentage,
      'is_popular': isPopular,
      'features': features,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    credits,
    price,
    currency,
    bonusPercentage,
    isPopular,
    features,
    isActive,
    createdAt,
    updatedAt,
  ];
}
