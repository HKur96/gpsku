import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/commands_repository.dart';
import '../datasources/commands_remote_data_source.dart';
import '../models/command_payload_model.dart';
import '../models/command_type_model.dart';

/// Production implementation of [CommandsRepository] enforcing typed Failure mappings
/// and unmodifiable collections.
class CommandsRepositoryImpl implements CommandsRepository {
  final CommandsRemoteDataSource remoteDataSource;

  CommandsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CommandTypeModel>>> getSupportedCommands({
    required int deviceId,
    String? protocol,
    bool? textChannel,
    CancelToken? cancelToken,
  }) async {
    try {
      final commands = await remoteDataSource.getSupportedCommands(
        deviceId: deviceId,
        protocol: protocol,
        textChannel: textChannel,
        cancelToken: cancelToken,
      );
      return Right(List.unmodifiable(commands));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CommandPayloadModel>> sendCommand(
    CommandPayloadModel payload, {
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await remoteDataSource.sendCommand(
        payload,
        cancelToken: cancelToken,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, statusCode: e.statusCode));
    } on ForbiddenException catch (e) {
      return Left(ForbiddenFailure(e.message, statusCode: e.statusCode));
    } on ConnectionTimeoutException catch (e) {
      return Left(TimeoutFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message, statusCode: e.statusCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
