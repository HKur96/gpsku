import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/emulator/data/models/telemetry_packet_model.dart';

void main() {
  group('TelemetryPacketModel Unit Tests', () {
    final tFixedDate = DateTime.utc(2026, 11, 10, 8, 30, 0);
    final tFixedEpoch = tFixedDate.millisecondsSinceEpoch ~/ 1000;

    test(
      'TC-TPM-01: Instantiation with required fields sets defaults properly',
      () {
        final packet = TelemetryPacketModel(
          id: 'TRONTON-77',
          lat: -6.2088,
          lon: 106.8456,
          timestamp: tFixedDate,
        );

        expect(packet.id, 'TRONTON-77');
        expect(packet.uniqueId, 'TRONTON-77');
        expect(packet.lat, -6.2088);
        expect(packet.lon, 106.8456);
        expect(packet.timestamp, tFixedDate);
        expect(packet.epochSeconds, tFixedEpoch);
        expect(packet.valid, isTrue);
        expect(packet.speed, isNull);
        expect(packet.bearing, isNull);
        expect(packet.altitude, isNull);
        expect(packet.battery, isNull);
        expect(packet.accuracy, isNull);
        expect(packet.hdop, isNull);
        expect(packet.charge, isNull);
        expect(packet.driverUniqueId, isNull);
        expect(packet.attributes, isEmpty);
      },
    );

    test(
      'TC-TPM-02: toOsmAndParams serializes all core parameters accurately',
      () {
        final packet = TelemetryPacketModel(
          id: 'DEV-101',
          lat: -6.1754,
          lon: 106.8272,
          timestamp: tFixedDate,
          speed: 25.4,
          bearing: 180.5,
          altitude: 45.0,
          battery: 88.5,
          accuracy: 3.5,
          hdop: 1.2,
          charge: true,
          driverUniqueId: 'RFID-9988',
          valid: true,
          attributes: const {'ignition': true, 'fuel': 72.5, 'temp': 'cold'},
        );

        final params = packet.toOsmAndParams();

        expect(params['id'], 'DEV-101');
        expect(params['lat'], '-6.1754');
        expect(params['lon'], '106.8272');
        expect(params['timestamp'], tFixedEpoch.toString());
        expect(params['speed'], '25.4');
        expect(params['bearing'], '180.5');
        expect(params['altitude'], '45.0');
        expect(params['batt'], '88.5'); // OsmAnd maps 'batt' to battery level
        expect(params['accuracy'], '3.5');
        expect(params['hdop'], '1.2');
        expect(params['charge'], 'true');
        expect(params['driverUniqueId'], 'RFID-9988');
        expect(params['valid'], 'true');
        expect(params['ignition'], 'true');
        expect(params['fuel'], '72.5');
        expect(params['temp'], 'cold');
      },
    );

    test(
      'TC-TPM-03: toOsmAndParams omits null optional parameters cleanly',
      () {
        final packet = TelemetryPacketModel(
          id: 'MINIMAL-1',
          lat: -7.2504,
          lon: 112.7688,
          timestamp: tFixedDate,
        );

        final params = packet.toOsmAndParams();

        expect(params.containsKey('id'), isTrue);
        expect(params.containsKey('lat'), isTrue);
        expect(params.containsKey('lon'), isTrue);
        expect(params.containsKey('timestamp'), isTrue);
        expect(params.containsKey('valid'), isTrue);

        expect(params.containsKey('speed'), isFalse);
        expect(params.containsKey('bearing'), isFalse);
        expect(params.containsKey('altitude'), isFalse);
        expect(params.containsKey('batt'), isFalse);
        expect(params.containsKey('accuracy'), isFalse);
        expect(params.containsKey('hdop'), isFalse);
        expect(params.containsKey('charge'), isFalse);
        expect(params.containsKey('driverUniqueId'), isFalse);
      },
    );

    test(
      'TC-TPM-04: toQueryString encodes into RFC compliant query string',
      () {
        final packet = TelemetryPacketModel(
          id: 'TRUCK 01',
          lat: -6.2000,
          lon: 106.8000,
          timestamp: tFixedDate,
          speed: 10.0,
        );

        final qs = packet.toQueryString();

        expect(qs, contains('id=TRUCK+01'));
        expect(qs, contains('lat=-6.2'));
        expect(qs, contains('lon=106.8'));
        expect(qs, contains('speed=10.0'));
        expect(qs, contains('timestamp=$tFixedEpoch'));
      },
    );

    test(
      'TC-TPM-05: toUri builds target URI with host, port 5055 and parameters',
      () {
        final packet = TelemetryPacketModel(
          id: 'DEV-101',
          lat: -6.2088,
          lon: 106.8456,
          timestamp: tFixedDate,
        );

        final uri = packet.toUri('http://10.0.2.2:8082');

        expect(uri.scheme, 'http');
        expect(uri.host, '10.0.2.2');
        expect(uri.port, 5055);
        expect(uri.path, '/');
        expect(uri.queryParameters['id'], 'DEV-101');
        expect(uri.queryParameters['lat'], '-6.2088');
        expect(uri.queryParameters['lon'], '106.8456');
      },
    );

    test(
      'TC-TPM-06: Speed conversions between km/h and knots work symmetrically',
      () {
        const speedKnots = 10.0;
        final speedKmh = TelemetryPacketModel.knotsToKmh(speedKnots);
        expect(speedKmh, closeTo(18.52, 0.01));

        final convertedBack = TelemetryPacketModel.kmhToKnots(speedKmh);
        expect(convertedBack, closeTo(speedKnots, 0.01));

        final packet = TelemetryPacketModel(
          id: 'S-1',
          lat: 0.0,
          lon: 0.0,
          speed: speedKnots,
        );
        expect(packet.speedKmh, closeTo(18.52, 0.01));
      },
    );

    test(
      'TC-TPM-07: fromJson parses JSON with epoch integer and string timestamp',
      () {
        final jsonWithEpoch = {
          'id': 'CAR-42',
          'lat': -6.9175,
          'lon': 107.6191,
          'timestamp': tFixedEpoch,
          'speed': 30.5,
          'bearing': 90.0,
          'altitude': 750.0,
          'battery': 95.0,
          'accuracy': 2.0,
          'hdop': 0.8,
          'charge': true,
          'driverUniqueId': 'DRV-1',
          'valid': true,
          'attributes': {'aircon': 'on'},
        };

        final parsed = TelemetryPacketModel.fromJson(jsonWithEpoch);

        expect(parsed.id, 'CAR-42');
        expect(parsed.lat, -6.9175);
        expect(parsed.lon, 107.6191);
        expect(parsed.epochSeconds, tFixedEpoch);
        expect(parsed.speed, 30.5);
        expect(parsed.bearing, 90.0);
        expect(parsed.altitude, 750.0);
        expect(parsed.battery, 95.0);
        expect(parsed.accuracy, 2.0);
        expect(parsed.hdop, 0.8);
        expect(parsed.charge, isTrue);
        expect(parsed.driverUniqueId, 'DRV-1');
        expect(parsed.valid, isTrue);
        expect(parsed.attributes['aircon'], 'on');

        // Test with ISO string timestamp
        final jsonWithIso = {
          'uniqueId': 'CAR-43',
          'latitude': -6.9175,
          'longitude': 107.6191,
          'timestamp': tFixedDate.toIso8601String(),
        };
        final parsedIso = TelemetryPacketModel.fromJson(jsonWithIso);
        expect(parsedIso.id, 'CAR-43');
        expect(parsedIso.epochSeconds, tFixedEpoch);
      },
    );

    test('TC-TPM-08: toJson produces standard JSON map serialization', () {
      final packet = TelemetryPacketModel(
        id: 'UNIT-007',
        lat: -8.4095,
        lon: 115.1889,
        timestamp: tFixedDate,
        speed: 15.0,
        bearing: 45.0,
        altitude: 120.0,
        battery: 60.0,
        attributes: const {'door': 'closed'},
      );

      final json = packet.toJson();

      expect(json['id'], 'UNIT-007');
      expect(json['lat'], -8.4095);
      expect(json['lon'], 115.1889);
      expect(json['timestamp'], tFixedDate.toIso8601String());
      expect(json['speed'], 15.0);
      expect(json['bearing'], 45.0);
      expect(json['altitude'], 120.0);
      expect(json['battery'], 60.0);
      expect(json['attributes'], {'door': 'closed'});
    });

    test(
      'TC-TPM-09: copyWith creates modified instance while keeping unmodified values',
      () {
        final original = TelemetryPacketModel(
          id: 'ORIGINAL-1',
          lat: 1.0,
          lon: 2.0,
          timestamp: tFixedDate,
          speed: 10.0,
        );

        final copy = original.copyWith(lat: 3.0, speed: 20.0);

        expect(copy.id, 'ORIGINAL-1');
        expect(copy.lat, 3.0);
        expect(copy.lon, 2.0);
        expect(copy.speed, 20.0);
        expect(original.lat, 1.0);
        expect(original.speed, 10.0);
      },
    );

    test(
      'TC-TPM-10: Value equality and hashCode enforce value-based comparison',
      () {
        final p1 = TelemetryPacketModel(
          id: 'SAME-ID',
          lat: 10.0,
          lon: 20.0,
          timestamp: tFixedDate,
          attributes: const {'tag': 'alpha'},
        );

        final p2 = TelemetryPacketModel(
          id: 'SAME-ID',
          lat: 10.0,
          lon: 20.0,
          timestamp: tFixedDate,
          attributes: const {'tag': 'alpha'},
        );

        final p3 = p1.copyWith(lat: 10.0001);

        expect(p1, equals(p2));
        expect(p1.hashCode, equals(p2.hashCode));
        expect(p1, isNot(equals(p3)));
      },
    );

    test('TC-TPM-11: attributes map is strictly unmodifiable', () {
      final packet = TelemetryPacketModel(
        id: 'IMMUTABLE-1',
        lat: 0.0,
        lon: 0.0,
        attributes: {'status': 'ok'},
      );

      expect(
        () => packet.attributes['newKey'] = 'value',
        throwsUnsupportedError,
      );
    });
  });
}
