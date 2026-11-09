import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/computed_attribute_model.dart';
import '../../data/models/computed_attribute_test_result_model.dart';

/// Contract for managing Computed Attributes (JEXL Formulas) in Traccar (Feature F-38).
abstract class ComputedAttributesRepository {
  /// Fetches computed attributes based on filters.
  /// Enforces unmodifiable collection on success.
  Future<Either<Failure, List<ComputedAttributeModel>>> getComputedAttributes({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    CancelToken? cancelToken,
  });

  /// Creates a new computed attribute.
  Future<Either<Failure, ComputedAttributeModel>> createComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  });

  /// Updates an existing computed attribute.
  Future<Either<Failure, ComputedAttributeModel>> updateComputedAttribute(
    ComputedAttributeModel attribute, {
    CancelToken? cancelToken,
  });

  /// Deletes a computed attribute by [id].
  Future<Either<Failure, void>> deleteComputedAttribute(
    int id, {
    CancelToken? cancelToken,
  });

  /// Evaluates an attribute expression against the latest position of [deviceId].
  Future<Either<Failure, ComputedAttributeTestResultModel>>
  testComputedAttribute({
    required int deviceId,
    required ComputedAttributeModel attribute,
    CancelToken? cancelToken,
  });

  /// Links a device to a computed attribute via `/api/permissions`.
  Future<Either<Failure, void>> linkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Unlinks a device from a computed attribute via `/api/permissions`.
  Future<Either<Failure, void>> unlinkDeviceAttribute({
    required int deviceId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Links a fleet group to a computed attribute via `/api/permissions`.
  Future<Either<Failure, void>> linkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  });

  /// Unlinks a fleet group from a computed attribute via `/api/permissions`.
  Future<Either<Failure, void>> unlinkGroupAttribute({
    required int groupId,
    required int attributeId,
    CancelToken? cancelToken,
  });
}
