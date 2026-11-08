import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/commands/data/models/command_payload_model.dart';

void main() {
  group('CommandPayloadModel Unit Tests', () {
    test('TC-CPM-01: Deserializes full JSON payload accurately', () {
      final json = {
        'id': 12,
        'deviceId': 42,
        'type': 'custom',
        'description': 'Custom SMS Command',
        'textChannel': true,
        'attributes': {'data': 'STATUS#'},
      };

      final model = CommandPayloadModel.fromJson(json, isQueued: true);

      expect(model.id, equals(12));
      expect(model.deviceId, equals(42));
      expect(model.type, equals('custom'));
      expect(model.description, equals('Custom SMS Command'));
      expect(model.textChannel, isTrue);
      expect(model.attributes['data'], equals('STATUS#'));
      expect(model.isQueued, isTrue);
    });

    test(
      'TC-CPM-02: Safely handles missing optional fields with default fallbacks',
      () {
        final json = {'deviceId': 99, 'type': 'engineStop'};

        final model = CommandPayloadModel.fromJson(json);

        expect(model.id, equals(0));
        expect(model.deviceId, equals(99));
        expect(model.type, equals('engineStop'));
        expect(model.description, isNull);
        expect(model.textChannel, isFalse);
        expect(model.attributes, isEmpty);
        expect(model.isQueued, isFalse);
      },
    );

    test('TC-CPM-03: Enforces unmodifiable collection for attributes map', () {
      final model = CommandPayloadModel(
        deviceId: 1,
        type: 'engineStop',
        attributes: {'frequency': 30},
      );

      expect(
        () => model.attributes['frequency'] = 60,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('TC-CPM-04: toJson generates expected body omitting id when 0', () {
      final model = CommandPayloadModel(
        deviceId: 55,
        type: 'engineResume',
        textChannel: false,
        attributes: {'test': 123},
      );

      final json = model.toJson();

      expect(json['deviceId'], equals(55));
      expect(json['type'], equals('engineResume'));
      expect(json['textChannel'], isFalse);
      expect(json['attributes'], equals({'test': 123}));
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('isQueued'), isFalse);
    });

    test('TC-CPM-05: toJson includes id and description when present', () {
      final model = CommandPayloadModel(
        id: 7,
        deviceId: 55,
        type: 'custom',
        description: 'Send test command',
        textChannel: true,
        attributes: const {},
      );

      final json = model.toJson();

      expect(json['id'], equals(7));
      expect(json['description'], equals('Send test command'));
      expect(json['textChannel'], isTrue);
    });

    test(
      'TC-CPM-06: Value equality verifies deep attribute map comparisons',
      () {
        final model1 = CommandPayloadModel(
          deviceId: 10,
          type: 'custom',
          attributes: {'data': 'PARAM'},
        );
        final model2 = CommandPayloadModel(
          deviceId: 10,
          type: 'custom',
          attributes: {'data': 'PARAM'},
        );
        final model3 = CommandPayloadModel(
          deviceId: 10,
          type: 'custom',
          attributes: {'data': 'DIFF'},
        );

        expect(model1, equals(model2));
        expect(model1.hashCode, equals(model2.hashCode));
        expect(model1, isNot(equals(model3)));
      },
    );

    test('TC-CPM-07: copyWith replicates and updates targeted fields', () {
      final model = CommandPayloadModel(
        deviceId: 10,
        type: 'engineStop',
        isQueued: false,
      );

      final updated = model.copyWith(
        isQueued: true,
        description: 'Queued via server',
      );

      expect(updated.deviceId, equals(10));
      expect(updated.type, equals('engineStop'));
      expect(updated.isQueued, isTrue);
      expect(updated.description, equals('Queued via server'));
    });

    test('TC-CPM-08: toString produces readable debugging description', () {
      final model = CommandPayloadModel(deviceId: 10, type: 'engineStop');
      expect(model.toString(), contains('deviceId: 10'));
      expect(model.toString(), contains('type: engineStop'));
    });
  });
}
