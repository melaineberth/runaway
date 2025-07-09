class ValidatedPurchase {
  final bool valid;
  final int creditsAdded;

  const ValidatedPurchase({
    required this.valid,
    required this.creditsAdded,
  });

  factory ValidatedPurchase.fromJson(Map<String, dynamic> json) =>
      ValidatedPurchase(
        valid: json['valid'] as bool,
        creditsAdded: json['creditsAdded'] as int? ?? 0,
      );
}
