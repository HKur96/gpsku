import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/commands/data/models/command_type_model.dart';

void main() {
  group('CommandTypeModel Unit Tests', () {
    test('TC-CTM-01: Deserializes valid JSON accurately', () {
      final json = {'type': 'engineStop'};
      final model = CommandTypeModel.fromJson(json);

      expect(model.type, equals('engineStop'));
    });

    test('TC-CTM-02: Safely handles null or missing type field', () {
      final json = <String, dynamic>{};
      final model = CommandTypeModel.fromJson(json);

      expect(model.type, equals(''));
    });

    test('TC-CTM-03: Serializes toJson correctly', () {
      const model = CommandTypeModel(type: 'engineResume');
      final json = model.toJson();

      expect(json, equals({'type': 'engineResume'}));
    });

    test('TC-CTM-04: Value equality and hashCode operate correctly', () {
      const model1 = CommandTypeModel(type: 'custom');
      const model2 = CommandTypeModel(type: 'custom');
      const model3 = CommandTypeModel(type: 'engineStop');

      expect(model1, equals(model2));
      expect(model1.hashCode, equals(model2.hashCode));
      expect(model1, isNot(equals(model3)));
    });

    test(
      'TC-CTM-05: Standard Traccar command type constants are well-defined',
      () {
        expect(CommandTypeModel.typeCustom, equals('custom'));
        expect(CommandTypeModel.typeEngineStop, equals('engineStop'));
        expect(CommandTypeModel.typeEngineResume, equals('engineResume'));
        expect(CommandTypeModel.typePositionSingle, equals('positionSingle'));
        expect(
          CommandTypeModel.typePositionPeriodic,
          equals('positionPeriodic'),
        );
        expect(CommandTypeModel.typePositionStop, equals('positionStop'));
        expect(CommandTypeModel.typeAlarmArm, equals('alarmArm'));
        expect(CommandTypeModel.typeAlarmDisarm, equals('alarmDisarm'));
        expect(CommandTypeModel.typeRebootDevice, equals('rebootDevice'));
        expect(CommandTypeModel.typePowerOff, equals('powerOff'));
        expect(CommandTypeModel.typeSendSms, equals('sendSms'));
      },
    );

    test('TC-CTM-06: toString returns informative representation', () {
      const model = CommandTypeModel(type: 'rebootDevice');
      expect(model.toString(), equals('CommandTypeModel(type: rebootDevice)'));
    });
  });
}
