import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/notifications/data/models/notification_model.dart';
import 'package:gpsku/features/notifications/data/models/notification_type_model.dart';

void main() {
  group('NotificationModel Unit Tests', () {
    final fullNotificationJson = <String, dynamic>{
      'id': 10,
      'type': 'alarm',
      'description': 'Emergency SOS Alert',
      'always': true,
      'notificators': 'web, mail, firebase',
      'calendarId': 2,
      'commandId': 5,
      'attributes': <String, dynamic>{'alarms': 'sos,overspeed'},
    };

    test('TC-NOT-01: parses complete Notification JSON correctly', () {
      final model = NotificationModel.fromJson(fullNotificationJson);

      expect(model.id, 10);
      expect(model.type, 'alarm');
      expect(model.description, 'Emergency SOS Alert');
      expect(model.always, isTrue);
      expect(model.notificators, 'web, mail, firebase');
      expect(model.calendarId, 2);
      expect(model.commandId, 5);
      expect(model.attributes['alarms'], 'sos,overspeed');
    });

    test('TC-NOT-02: parses minimal Notification JSON with safe defaults', () {
      final minimalJson = <String, dynamic>{'id': 20, 'type': 'deviceOnline'};

      final model = NotificationModel.fromJson(minimalJson);

      expect(model.id, 20);
      expect(model.type, 'deviceOnline');
      expect(model.description, isNull);
      expect(model.always, isFalse);
      expect(model.notificators, '');
      expect(model.calendarId, 0);
      expect(model.commandId, 0);
      expect(model.attributes, isEmpty);
    });

    test('TC-NOT-03: toJson round-trip parity', () {
      final original = NotificationModel(
        id: 30,
        type: 'geofenceEnter',
        description: 'Zone Entry Notice',
        always: false,
        notificators: 'web,firebase',
        calendarId: 1,
        commandId: 0,
        attributes: const {'speedThreshold': 80},
      );

      final json = original.toJson();
      final reconstructed = NotificationModel.fromJson(json);

      expect(reconstructed, equals(original));
      expect(json['id'], 30);
      expect(json['type'], 'geofenceEnter');
      expect(json['description'], 'Zone Entry Notice');
      expect(json['always'], isFalse);
      expect(json['notificators'], 'web,firebase');
      expect(json['calendarId'], 1);
      expect(json['commandId'], 0);
      expect(json['attributes']['speedThreshold'], 80);
    });

    test('TC-NOT-04: copyWith modifies fields immutably', () {
      final original = NotificationModel(
        id: 1,
        type: 'alarm',
        notificators: 'web',
      );

      final updated = original.copyWith(
        notificators: 'web,firebase',
        always: true,
      );

      expect(updated.id, 1);
      expect(updated.notificators, 'web,firebase');
      expect(updated.always, isTrue);
      expect(original.notificators, 'web');
      expect(original.always, isFalse);
    });

    test('TC-NOT-05: value equality and hashCode consistency', () {
      final notifA = NotificationModel(
        id: 5,
        type: 'deviceMoving',
        notificators: 'web',
      );
      final notifB = NotificationModel(
        id: 5,
        type: 'deviceMoving',
        notificators: 'web',
      );
      final notifC = NotificationModel(
        id: 5,
        type: 'deviceMoving',
        notificators: 'firebase',
      );

      expect(notifA, equals(notifB));
      expect(notifA.hashCode, equals(notifB.hashCode));
      expect(notifA, isNot(equals(notifC)));
    });

    test('TC-NOT-06: notificatorList parsing and channel helper methods', () {
      final notif = NotificationModel(
        id: 1,
        type: 'alarm',
        notificators: 'web, mail, firebase, sms ',
      );

      final list = notif.notificatorList;
      expect(list, ['web', 'mail', 'firebase', 'sms']);
      expect(notif.hasNotificator('web'), isTrue);
      expect(notif.hasNotificator('WEB'), isTrue); // case-insensitive
      expect(notif.hasNotificator('firebase'), isTrue);
      expect(notif.hasNotificator('mail'), isTrue);
      expect(notif.hasNotificator('sms'), isTrue);
      expect(notif.hasNotificator('telegram'), isFalse);

      expect(notif.hasWeb, isTrue);
      expect(notif.hasFirebase, isTrue);
      expect(notif.hasMail, isTrue);
      expect(notif.hasSms, isTrue);
    });

    test('TC-NOT-07: empty notificators string returns empty list', () {
      final notif = NotificationModel(
        id: 2,
        type: 'alarm',
        notificators: '  , ,, ',
      );

      expect(notif.notificatorList, isEmpty);
      expect(notif.hasWeb, isFalse);
      expect(notif.hasFirebase, isFalse);
    });
  });

  group('NotificationTypeModel Unit Tests', () {
    test('TC-NT-01: parses and serializes correctly', () {
      final json = {'type': 'deviceOnline', 'name': 'Device Online'};
      final model = NotificationTypeModel.fromJson(json);

      expect(model.type, 'deviceOnline');
      expect(model.name, 'Device Online');
      expect(model.toJson(), json);
    });

    test('TC-NT-02: equality and copyWith', () {
      final a = const NotificationTypeModel(type: 'web');
      final b = const NotificationTypeModel(type: 'web');
      final c = a.copyWith(name: 'Web Browser');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(c.name, 'Web Browser');
      expect(a, isNot(equals(c)));
    });
  });
}
