import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/share_link_model.dart';

/// Domain repository contract for generating public vehicle & fleet share links.
///
/// Implements Feature F-37 (Tautan Berbagi Pelacakan Publik).
abstract class ShareRepository {
  /// Generates a public shareable tracking link for a single specific vehicle.
  ///
  /// [deviceId] is the target Traccar device ID.
  /// [duration] is the validity window from now (e.g., 1 hour, 24 hours, 7 days).
  ///
  /// Returns [ShareLinkModel] containing the signed token, expiration timestamp,
  /// and fully qualified shareable URL.
  Future<Either<Failure, ShareLinkModel>> generateShareLink(
    int deviceId,
    Duration duration, {
    CancelToken? cancelToken,
  });

  /// Generates a public shareable tracking link for an entire fleet group.
  ///
  /// [groupId] is the target Traccar group ID.
  /// [duration] is the validity window from now.
  Future<Either<Failure, ShareLinkModel>> generateGroupShareLink(
    int groupId,
    Duration duration, {
    CancelToken? cancelToken,
  });
}
