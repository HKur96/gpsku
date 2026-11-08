/// Status of the route telemetry playback animation loop.
enum PlaybackStatus {
  /// No route loaded or player has been reset.
  idle,

  /// Actively animating and stepping forward through historical fixes.
  playing,

  /// Temporarily paused by user or during timeline scrubbing.
  paused,

  /// Reached the terminus of the route.
  completed,
}

/// Speed multipliers for route playback simulation.
enum PlaybackSpeed {
  speed1x(1.0, '1x'),
  speed2x(2.0, '2x'),
  speed4x(4.0, '4x'),
  speed8x(8.0, '8x');

  final double multiplier;
  final String label;

  const PlaybackSpeed(this.multiplier, this.label);
}
