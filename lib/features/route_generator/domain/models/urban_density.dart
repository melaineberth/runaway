enum UrbanDensity {
  urban(
    id: 'urban',
    title: 'Urbain',
    description: 'Principalement en ville',
    greenSpaceRatio: 0.1,
    poiDensity: 'high',
  ),
  mixed(
    id: 'mixed',
    title: 'Mixte',
    description: 'Mélange ville et nature',
    greenSpaceRatio: 0.5,
    poiDensity: 'medium',
  ),
  nature(
    id: 'nature',
    title: 'Nature',
    description: 'Principalement en nature',
    greenSpaceRatio: 0.9,
    poiDensity: 'low',
  );

  final String id;
  final String title;
  final String description;
  final double greenSpaceRatio;
  final String poiDensity;

  const UrbanDensity({
    required this.id,
    required this.title,
    required this.description,
    required this.greenSpaceRatio,
    required this.poiDensity,
  });
}
