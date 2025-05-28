
import 'package:runaway/features/home/domain/models/maps_styles.dart';

class MapsParameters {
  final MapsStyles mapsStyles;

  const MapsParameters({
    required this.mapsStyles,
  });

  MapsParameters copyWith({
    MapsStyles? mapsStyles,
  }) {
    return MapsParameters(
      mapsStyles: mapsStyles ?? this.mapsStyles,
    );
  }

  Map<String, dynamic> toJson() => {
    'maps_styles': mapsStyles.id,
  };
}