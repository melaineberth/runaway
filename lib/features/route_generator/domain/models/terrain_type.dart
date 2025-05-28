enum TerrainType {
  flat(
    id: 'flat',
    title: 'Plat',
    description: 'Terrain plat avec peu de dénivelé',
    elevationGain: 0.0, // % du parcours
    maxElevationGain: 50, // m/km
  ),
  mixed(
    id: 'mixed',
    title: 'Mixte',
    description: 'Terrain varié avec dénivelé modéré',
    elevationGain: 0.5,
    maxElevationGain: 100,
  ),
  hilly(
    id: 'hilly',
    title: 'Vallonné',
    description: 'Terrain avec fort dénivelé',
    elevationGain: 1.0,
    maxElevationGain: 200,
  );

  final String id;
  final String title;
  final String description;
  final double elevationGain;
  final int maxElevationGain;

  const TerrainType({
    required this.id,
    required this.title,
    required this.description,
    required this.elevationGain,
    required this.maxElevationGain,
  });
}
