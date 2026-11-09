import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/share_link_model.dart';
import '../../domain/repositories/share_repository.dart';

/// State management for generating and managing temporary public tracking share links.
///
/// Implements Feature F-37 (Tautan Berbagi Pelacakan Publik).
class ShareProvider extends ChangeNotifier {
  final ShareRepository repository;

  ShareProvider({required this.repository});

  ShareLinkModel? _shareLink;
  bool _isLoading = false;
  Failure? _failure;
  Duration _selectedDuration = const Duration(hours: 24);

  /// Standard duration presets supported by GPSku.
  static const List<Duration> defaultPresets = [
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(hours: 24),
    Duration(days: 7),
  ];

  /// Active generated share link, if any.
  ShareLinkModel? get shareLink => _shareLink;

  /// Whether an HTTP generation request is currently pending.
  bool get isLoading => _isLoading;

  /// The failure returned by repository, if any.
  Failure? get failure => _failure;

  /// Human-readable error message.
  String? get errorMessage => _failure?.message;

  /// True if failure is due to an active share link already existing (HTTP 409 Conflict).
  bool get isConflict =>
      _failure is ConflictFailure || _failure?.statusCode == 409;

  /// Active selected duration preset.
  Duration get selectedDuration => _selectedDuration;

  /// True if a share link has been successfully generated and is currently active.
  bool get hasLink => _shareLink != null;

  /// Formats duration preset into clean localized Indonesian text.
  static String formatDurationPreset(Duration duration) {
    if (duration.inDays >= 7) return '7 Hari';
    if (duration.inDays >= 1) return '24 Jam';
    if (duration.inHours >= 6) return '6 Jam';
    if (duration.inHours >= 1) return '1 Jam';
    return '${duration.inMinutes} Menit';
  }

  /// Sets the selected duration preset.
  void setDuration(Duration duration) {
    if (_selectedDuration != duration) {
      _selectedDuration = duration;
      notifyListeners();
    }
  }

  /// Generates a public shareable link for a vehicle.
  Future<bool> generateLink(
    int deviceId, {
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    _isLoading = true;
    _failure = null;
    notifyListeners();

    final dur = duration ?? _selectedDuration;
    final result = await repository.generateShareLink(
      deviceId,
      dur,
      cancelToken: cancelToken,
    );

    return result.fold(
      (f) {
        _failure = f;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (link) {
        _shareLink = link;
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Generates a public shareable link for an entire group.
  Future<bool> generateGroupLink(
    int groupId, {
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    _isLoading = true;
    _failure = null;
    notifyListeners();

    final dur = duration ?? _selectedDuration;
    final result = await repository.generateGroupShareLink(
      groupId,
      dur,
      cancelToken: cancelToken,
    );

    return result.fold(
      (f) {
        _failure = f;
        _isLoading = false;
        notifyListeners();
        return false;
      },
      (link) {
        _shareLink = link;
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Clears active state and resets provider.
  void clearState() {
    _shareLink = null;
    _failure = null;
    _isLoading = false;
    notifyListeners();
  }
}
