import '../../features/fleet/data/models/position_model.dart';

/// Deterministic guard preventing telematics marker jump-back caused by
/// out-of-order packets between rapid WebSocket streams and slower REST responses.
class PositionOrderingGuard {
  /// Evaluates whether [incoming] position is strictly newer than [existing] position.
  /// Multi-criteria deterministic ordering verified in Spike 6:
  /// 1. FixTime: Satellite GPS fix timestamp takes primary precedence.
  /// 2. ID: When fixTime is identical, higher auto-increment DB PK wins.
  /// 3. ServerTime: Ingestion server timestamp breaks remaining ties.
  static bool isPositionNewer(PositionModel incoming, PositionModel existing) {
    // Criterion 1: Satellite fixTime is strictly newer
    if (incoming.fixTime.isAfter(existing.fixTime)) {
      return true;
    }

    // Criterion 2: Same fixTime (split-second batch fix), evaluate auto-increment database PK
    if (incoming.fixTime.isAtSameMomentAs(existing.fixTime)) {
      if (incoming.id > 0 && existing.id > 0) {
        return incoming.id > existing.id;
      }
      // Criterion 3: One or both lack persistent ID, compare ingestion serverTime
      return incoming.serverTime.isAfter(existing.serverTime);
    }

    // Incoming fixTime is in the past -> stale / obsolete
    return false;
  }

  /// Determines whether an existing position should be updated.
  /// Always returns true if [existing] is null.
  static bool shouldUpdate(PositionModel? existing, PositionModel incoming) {
    if (existing == null) return true;
    return isPositionNewer(incoming, existing);
  }
}
