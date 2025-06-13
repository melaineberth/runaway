class NavigationCameraConfig {
  final double zoom;
  final double pitch;
  final int updateIntervalMs;
  final double minMovementDistance;
  final double maxBearingChange;
  final int positionHistorySize;

  const NavigationCameraConfig({
    this.zoom = 18.0,
    this.pitch = 65.0,
    this.updateIntervalMs = 1000,
    this.minMovementDistance = 5.0,
    this.maxBearingChange = 15.0,
    this.positionHistorySize = 10,
  });
}