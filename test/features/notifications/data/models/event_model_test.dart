import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/notifications/data/models/event_model.dart';

void main() {
  group('EventModel Unit Tests', () {
    const rawIsoTime = '2026-11-08T15:30:00.000Z';
    final sampleTime = DateTime.parse(rawIsoTime);

    final fullEventJson = <String, dynamic>{
      'id': 101,
      'type': 'alarm',
      'eventTime': rawIsoTime,
      'deviceId': 42,
      'positionId': 999,
      'geofenceId': 5,
      'maintenanceId': 12,
      'attributes': <String, dynamic>{
        'alarm': 'sos',
        'message': 'Emergency button pressed',
      },
    };

    test('TC-EVT-01: parses complete Event JSON correctly', () {
      final model = EventModel.fromJson(fullEventJson);

      expect(model.id, 101);
      expect(model.type, 'alarm');
      expect(model.eventTime, sampleTime);
      expect(model.deviceId, 42);
      expect(model.positionId, 999);
      expect(model.geofenceId, 5);
      expect(model.maintenanceId, 12);
      expect(model.attributes['alarm'], 'sos');
      expect(model.attributes['message'], 'Emergency button pressed');
    });

    test('TC-EVT-02: parses minimal Event JSON with safe defaults', () {
      final minimalJson = <String, dynamic>{'id': 202, 'type': 'deviceOnline'};

      final model = EventModel.fromJson(minimalJson);

      expect(model.id, 202);
      expect(model.type, 'deviceOnline');
      expect(model.eventTime, isNull);
      expect(model.deviceId, 0);
      expect(model.positionId, 0);
      expect(model.geofenceId, 0);
      expect(model.maintenanceId, 0);
      expect(model.attributes, isEmpty);
    });

    test('TC-EVT-03: toJson serializes correctly for round-trip parity', () {
      final original = EventModel(
        id: 303,
        type: EventModel.typeGeofenceEnter,
        eventTime: sampleTime,
        deviceId: 15,
        positionId: 789,
        geofenceId: 3,
        maintenanceId: 0,
        attributes: const {'geofenceName': 'HQ Yard'},
      );

      final json = original.toJson();
      final reconstructed = EventModel.fromJson(json);

      expect(reconstructed, equals(original));
      expect(json['id'], 303);
      expect(json['type'], EventModel.typeGeofenceEnter);
      expect(json['eventTime'], rawIsoTime);
      expect(json['deviceId'], 15);
      expect(json['positionId'], 789);
      expect(json['geofenceId'], 3);
      expect(json['attributes']['geofenceName'], 'HQ Yard');
    });

    test('TC-EVT-04: copyWith updates specified fields immutably', () {
      final original = EventModel(
        id: 1,
        type: 'deviceMoving',
        deviceId: 10,
        attributes: const {'speed': 60.5},
      );

      final updated = original.copyWith(
        id: 2,
        type: 'deviceStopped',
        attributes: const {'speed': 0.0},
      );

      expect(updated.id, 2);
      expect(updated.type, 'deviceStopped');
      expect(updated.deviceId, 10);
      expect(updated.attributes['speed'], 0.0);
      expect(original.id, 1);
    });

    test('TC-EVT-05: value equality and hashCode consistency', () {
      final eventA = EventModel(
        id: 10,
        type: 'alarm',
        deviceId: 5,
        attributes: const {'alarm': 'vibration'},
      );
      final eventB = EventModel(
        id: 10,
        type: 'alarm',
        deviceId: 5,
        attributes: const {'alarm': 'vibration'},
      );
      final eventC = EventModel(
        id: 10,
        type: 'alarm',
        deviceId: 5,
        attributes: const {'alarm': 'powerCut'},
      );

      expect(eventA, equals(eventB));
      expect(eventA.hashCode, equals(eventB.hashCode));
      expect(eventA, isNot(equals(eventC)));
    });

    test('TC-EVT-06: alarm and SOS detection getters', () {
      final sosEvent = EventModel(
        id: 1,
        type: EventModel.typeAlarm,
        attributes: const {'alarm': 'sos'},
      );
      expect(sosEvent.isAlarm, isTrue);
      expect(sosEvent.alarmType, 'sos');
      expect(sosEvent.isSos, isTrue);

      final vibrationEvent = EventModel(
        id: 2,
        type: EventModel.typeAlarm,
        attributes: const {'alarm': 'vibration'},
      );
      expect(vibrationEvent.isAlarm, isTrue);
      expect(vibrationEvent.alarmType, 'vibration');
      expect(vibrationEvent.isSos, isFalse);

      final nonAlarm = EventModel(id: 3, type: EventModel.typeDeviceOnline);
      expect(nonAlarm.isAlarm, isFalse);
      expect(nonAlarm.isSos, isFalse);
    });

    test(
      'TC-EVT-07: overspeed detection for both type and alarm attribute',
      () {
        final speedTypeEvent = EventModel(
          id: 1,
          type: EventModel.typeDeviceOverspeed,
        );
        expect(speedTypeEvent.isOverspeed, isTrue);

        final speedAlarmEvent = EventModel(
          id: 2,
          type: EventModel.typeAlarm,
          attributes: const {'alarm': 'overspeed'},
        );
        expect(speedAlarmEvent.isOverspeed, isTrue);

        final movingEvent = EventModel(
          id: 3,
          type: EventModel.typeDeviceMoving,
        );
        expect(movingEvent.isOverspeed, isFalse);
      },
    );

    test('TC-EVT-08: geofence event detection', () {
      expect(
        EventModel(id: 1, type: EventModel.typeGeofenceEnter).isGeofence,
        isTrue,
      );
      expect(
        EventModel(id: 2, type: EventModel.typeGeofenceExit).isGeofence,
        isTrue,
      );
      expect(
        EventModel(id: 3, type: EventModel.typeGeofenceCrossed).isGeofence,
        isTrue,
      );
      expect(
        EventModel(id: 4, type: EventModel.typeDeviceMoving).isGeofence,
        isFalse,
      );
    });

    test('TC-EVT-09: device status change detection', () {
      expect(
        EventModel(id: 1, type: EventModel.typeDeviceOnline).isDeviceStatus,
        isTrue,
      );
      expect(
        EventModel(id: 2, type: EventModel.typeDeviceOffline).isDeviceStatus,
        isTrue,
      );
      expect(
        EventModel(id: 3, type: EventModel.typeDeviceUnknown).isDeviceStatus,
        isTrue,
      );
      expect(
        EventModel(id: 4, type: EventModel.typeDeviceInactive).isDeviceStatus,
        isTrue,
      );
      expect(
        EventModel(id: 5, type: EventModel.typeAlarm).isDeviceStatus,
        isFalse,
      );
    });

    test('TC-EVT-10: message extraction helper', () {
      final eventWithMessage = EventModel(
        id: 1,
        type: EventModel.typeCommandResult,
        attributes: const {'message': 'Engine cut-off executed successfully'},
      );
      expect(eventWithMessage.message, 'Engine cut-off executed successfully');

      final eventWithoutMessage = EventModel(
        id: 2,
        type: EventModel.typeDeviceOnline,
      );
      expect(eventWithoutMessage.message, isNull);
    });
  });
}
