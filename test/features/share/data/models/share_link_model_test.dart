import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/share/data/models/share_link_model.dart';

void main() {
  group('ShareLinkModel Unit Tests', () {
    final tExpiration = DateTime.utc(2026, 12, 31, 23, 59, 59);

    final tModel = ShareLinkModel(
      deviceId: 42,
      groupId: null,
      token: 'test_token_xyz_123',
      expiration: tExpiration,
      shareUrl: 'https://gpsku.app/?token=test_token_xyz_123',
      attributes: const {'recipient': 'PT Antigravity', 'speedLimit': 90},
    );

    test(
      'TC-SLM-01: Serializes to JSON and deserializes from JSON accurately',
      () {
        final json = tModel.toJson();

        expect(json['deviceId'], 42);
        expect(json['groupId'], isNull);
        expect(json['token'], 'test_token_xyz_123');
        expect(json['expiration'], tExpiration.toIso8601String());
        expect(json['shareUrl'], 'https://gpsku.app/?token=test_token_xyz_123');
        expect(json['attributes']['recipient'], 'PT Antigravity');
        expect(json['attributes']['speedLimit'], 90);

        final fromJson = ShareLinkModel.fromJson(json);

        expect(fromJson.deviceId, tModel.deviceId);
        expect(fromJson.groupId, isNull);
        expect(fromJson.token, tModel.token);
        expect(fromJson.expiration.isAtSameMomentAs(tModel.expiration), isTrue);
        expect(fromJson.shareUrl, tModel.shareUrl);
        expect(fromJson.attributes, tModel.attributes);
        expect(fromJson, equals(tModel));
      },
    );

    test('TC-SLM-02: Enforces immutability on attributes map', () {
      final mutableAttributes = <String, dynamic>{'note': 'Urgent shipment'};
      final model = ShareLinkModel(
        deviceId: 10,
        token: 'token_abc',
        expiration: tExpiration,
        shareUrl: 'https://gpsku.app/?token=token_abc',
        attributes: mutableAttributes,
      );

      // Mutating original map after model creation must not affect model attributes
      mutableAttributes['note'] = 'Changed';
      expect(model.attributes['note'], 'Urgent shipment');

      // Attempting to modify model.attributes must throw UnsupportedError
      expect(
        () => model.attributes['newKey'] = 'Forbidden',
        throwsUnsupportedError,
      );
    });

    test(
      'TC-SLM-03: isExpired returns false for future timestamps and true for past timestamps',
      () {
        final futureModel = ShareLinkModel(
          deviceId: 10,
          token: 'token_future',
          expiration: DateTime.now().add(const Duration(hours: 2)),
          shareUrl: 'https://gpsku.app/?token=token_future',
        );
        expect(futureModel.isExpired, isFalse);

        final pastModel = ShareLinkModel(
          deviceId: 10,
          token: 'token_past',
          expiration: DateTime.now().subtract(const Duration(seconds: 10)),
          shareUrl: 'https://gpsku.app/?token=token_past',
        );
        expect(pastModel.isExpired, isTrue);
      },
    );

    test(
      'TC-SLM-04: remainingDuration returns positive duration or zero when expired',
      () {
        final activeModel = ShareLinkModel(
          deviceId: 10,
          token: 'token_active',
          expiration: DateTime.now().add(const Duration(minutes: 30)),
          shareUrl: 'https://gpsku.app/?token=token_active',
        );
        expect(
          activeModel.remainingDuration.inMinutes,
          greaterThanOrEqualTo(29),
        );

        final expiredModel = ShareLinkModel(
          deviceId: 10,
          token: 'token_expired',
          expiration: DateTime.now().subtract(const Duration(minutes: 5)),
          shareUrl: 'https://gpsku.app/?token=token_expired',
        );
        expect(expiredModel.remainingDuration, Duration.zero);
      },
    );

    test(
      'TC-SLM-05: isDeviceShare and isGroupShare flags behave correctly',
      () {
        final deviceModel = ShareLinkModel(
          deviceId: 99,
          groupId: null,
          token: 'token_dev',
          expiration: tExpiration,
          shareUrl: 'https://gpsku.app/?token=token_dev',
        );
        expect(deviceModel.isDeviceShare, isTrue);
        expect(deviceModel.isGroupShare, isFalse);

        final groupModel = ShareLinkModel(
          deviceId: 0,
          groupId: 5,
          token: 'token_grp',
          expiration: tExpiration,
          shareUrl: 'https://gpsku.app/?token=token_grp',
        );
        expect(groupModel.isDeviceShare, isFalse);
        expect(groupModel.isGroupShare, isTrue);
      },
    );

    test(
      'TC-SLM-06: buildShareUrl normalizes base URLs with or without trailing slash',
      () {
        expect(
          ShareLinkModel.buildShareUrl('http://10.0.2.2:8082', 'tok123'),
          'http://10.0.2.2:8082/?token=tok123',
        );

        expect(
          ShareLinkModel.buildShareUrl('https://gps.antigravity.id/', 'tok123'),
          'https://gps.antigravity.id/?token=tok123',
        );
      },
    );

    test(
      'TC-SLM-07: copyWith creates modified copies while maintaining unchanged fields',
      () {
        final updated = tModel.copyWith(
          token: 'new_token_456',
          shareUrl: 'https://gpsku.app/?token=new_token_456',
        );

        expect(updated.deviceId, tModel.deviceId);
        expect(updated.token, 'new_token_456');
        expect(updated.shareUrl, 'https://gpsku.app/?token=new_token_456');
        expect(updated.expiration, tModel.expiration);
        expect(updated.attributes, tModel.attributes);
      },
    );

    test(
      'TC-SLM-08: Value equality and hashCode compare fields accurately',
      () {
        final duplicate = ShareLinkModel(
          deviceId: 42,
          groupId: null,
          token: 'test_token_xyz_123',
          expiration: tExpiration,
          shareUrl: 'https://gpsku.app/?token=test_token_xyz_123',
          attributes: const {'recipient': 'PT Antigravity', 'speedLimit': 90},
        );

        expect(duplicate, equals(tModel));
        expect(duplicate.hashCode, equals(tModel.hashCode));

        final different = tModel.copyWith(deviceId: 99);
        expect(different, isNot(equals(tModel)));
      },
    );

    test(
      'TC-SLM-09: Deserializes millisecondsSinceEpoch timestamp in expiration',
      () {
        final msEpoch = tExpiration.millisecondsSinceEpoch;
        final jsonWithMs = {
          'deviceId': 42,
          'token': 'token_ms',
          'expiration': msEpoch,
          'shareUrl': 'https://gpsku.app/?token=token_ms',
        };

        final model = ShareLinkModel.fromJson(jsonWithMs);
        expect(model.expiration.millisecondsSinceEpoch, msEpoch);
        expect(model.token, 'token_ms');
      },
    );
  });
}
