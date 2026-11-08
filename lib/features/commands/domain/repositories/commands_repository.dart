import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../data/models/command_payload_model.dart';
import '../../data/models/command_type_model.dart';

/// Domain contract for managing remote device telematics commands.
abstract class CommandsRepository {
  /// Queries the list of compatible command types for [deviceId].
  /// Returns [Right] with an unmodifiable list of [CommandTypeModel],
  /// or [Left] with a domain [Failure].
  Future<Either<Failure, List<CommandTypeModel>>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  });

  /// Transmits a remote command payload to the Traccar backend.
  /// Returns [Right] with [CommandPayloadModel] reflecting execution outcome
  /// (including `isQueued = true` if HTTP 202 was returned),
  /// or [Left] with a domain [Failure].
  Future<Either<Failure, CommandPayloadModel>> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  });
}
