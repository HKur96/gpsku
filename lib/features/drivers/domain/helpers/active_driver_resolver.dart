import '../../../fleet/data/models/position_model.dart';
import '../../data/models/driver_model.dart';

/// Pure Dart domain helper to resolve the active driver entity for a vehicle
/// based on telemetry data ([PositionModel.attributes['driverUniqueId']]) or RFID/iButton identifiers.
class ActiveDriverResolver {
  const ActiveDriverResolver._();

  /// Resolves the active [DriverModel] from a given [position] and a catalog of [drivers].
  /// Matches [PositionModel.attributes['driverUniqueId']] against [DriverModel.uniqueId].
  /// Returns `null` if [position] is null, has no 'driverUniqueId' attribute, or no driver matches.
  static DriverModel? resolveFromPosition({
    required PositionModel? position,
    required List<DriverModel> drivers,
  }) {
    if (position == null) return null;
    final driverUniqueId = extractDriverUniqueId(position);
    if (driverUniqueId == null || driverUniqueId.isEmpty) return null;

    return resolveByUniqueId(driverUniqueId: driverUniqueId, drivers: drivers);
  }

  /// Extracts the `driverUniqueId` string from [position.attributes].
  /// Returns `null` if [position] is null, the attribute does not exist, or is blank.
  static String? extractDriverUniqueId(PositionModel? position) {
    if (position == null) return null;
    final raw = position.attributes['driverUniqueId'];
    if (raw == null) return null;
    final str = raw.toString().trim();
    return str.isNotEmpty ? str : null;
  }

  /// Resolves a [DriverModel] by its [driverUniqueId] (RFID / iButton identifier).
  /// Compares trimmed strings case-insensitively for maximum hardware/protocol compatibility.
  static DriverModel? resolveByUniqueId({
    required String? driverUniqueId,
    required List<DriverModel> drivers,
  }) {
    if (driverUniqueId == null) return null;
    final cleaned = driverUniqueId.trim();
    if (cleaned.isEmpty) return null;

    final target = cleaned.toLowerCase();
    for (final driver in drivers) {
      if (driver.uniqueId.trim().toLowerCase() == target) {
        return driver;
      }
    }
    return null;
  }

  /// Formats the display name for a driver:
  /// - Returns driver's name if a matched [driver] exists and is non-empty.
  /// - If no driver matched, returns the raw [fallbackUniqueId] (e.g. RFID tag).
  /// - Returns [defaultFallback] (e.g. 'Tanpa Pengemudi') if both are null or empty.
  static String formatDriverDisplay({
    DriverModel? driver,
    String? fallbackUniqueId,
    String defaultFallback = 'Tanpa Pengemudi',
  }) {
    if (driver != null && driver.name.trim().isNotEmpty) {
      return driver.name.trim();
    }
    if (fallbackUniqueId != null && fallbackUniqueId.trim().isNotEmpty) {
      return fallbackUniqueId.trim();
    }
    return defaultFallback;
  }
}
