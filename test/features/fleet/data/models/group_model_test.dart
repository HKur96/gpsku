import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/data/models/group_model.dart';

void main() {
  group('GroupModel - Serialization & Immutability Unit Tests', () {
    test(
      'TC-GRP-01: Deserialization from JSON with root group (groupId: 0 -> null)',
      () {
        final json = {
          'id': 1,
          'name': 'Regional Jabodetabek',
          'groupId': 0,
          'attributes': {'region': 'west', 'color': '#FF0000'},
        };

        final group = GroupModel.fromJson(json);

        expect(group.id, equals(1));
        expect(group.name, equals('Regional Jabodetabek'));
        expect(group.groupId, isNull);
        expect(group.isRoot, isTrue);
        expect(group.attributes['region'], equals('west'));
        expect(group.attributes['color'], equals('#FF0000'));
      },
    );

    test(
      'TC-GRP-02: Deserialization from JSON with child group (groupId: 10)',
      () {
        final json = {
          'id': 5,
          'name': 'Logistik Truk Berat',
          'groupId': 10,
          'attributes': <String, dynamic>{},
        };

        final group = GroupModel.fromJson(json);

        expect(group.id, equals(5));
        expect(group.name, equals('Logistik Truk Berat'));
        expect(group.groupId, equals(10));
        expect(group.isRoot, isFalse);
        expect(group.attributes, isEmpty);
      },
    );

    test(
      'TC-GRP-03: Deserialization handles missing/null attributes gracefully',
      () {
        final json = {'id': 2, 'name': 'Patroli Cepat'};

        final group = GroupModel.fromJson(json);

        expect(group.id, equals(2));
        expect(group.name, equals('Patroli Cepat'));
        expect(group.groupId, isNull);
        expect(group.isRoot, isTrue);
        expect(group.attributes, isEmpty);
      },
    );

    test('TC-GRP-04: Serialization to JSON outputs correct Traccar schema', () {
      const group = GroupModel(
        id: 7,
        name: 'Armada Khusus',
        groupId: 3,
        attributes: {'priority': 'high'},
      );

      final json = group.toJson();

      expect(json['id'], equals(7));
      expect(json['name'], equals('Armada Khusus'));
      expect(json['groupId'], equals(3));
      expect(json['attributes'], equals({'priority': 'high'}));
    });

    test(
      'TC-GRP-05: copyWith creates independent instance with updated properties',
      () {
        const original = GroupModel(
          id: 1,
          name: 'Original Group',
          groupId: null,
          attributes: {'tag': 'A'},
        );

        final updated = original.copyWith(
          name: 'Updated Group',
          groupId: 20,
          attributes: {'tag': 'B'},
        );

        expect(updated.id, equals(1));
        expect(updated.name, equals('Updated Group'));
        expect(updated.groupId, equals(20));
        expect(updated.attributes, equals({'tag': 'B'}));
        expect(
          original.name,
          equals('Original Group'),
        ); // Immutability preserved
      },
    );

    test('TC-GRP-06: Value equality and hashCode validation', () {
      const g1 = GroupModel(
        id: 10,
        name: 'G1',
        groupId: 5,
        attributes: {'k': 'v'},
      );
      const g2 = GroupModel(
        id: 10,
        name: 'G1',
        groupId: 5,
        attributes: {'k': 'v'},
      );
      const g3 = GroupModel(
        id: 11,
        name: 'G1',
        groupId: 5,
        attributes: {'k': 'v'},
      );

      expect(g1, equals(g2));
      expect(g1.hashCode, equals(g2.hashCode));
      expect(g1, isNot(equals(g3)));
    });
  });
}
