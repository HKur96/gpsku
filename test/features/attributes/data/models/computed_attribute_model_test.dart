import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_model.dart';
import 'package:gpsku/features/attributes/data/models/computed_attribute_test_result_model.dart';

void main() {
  group('ComputedAttributeModel Unit Tests', () {
    final tModel = const ComputedAttributeModel(
      id: 10,
      description: 'Sensor Level Bahan Bakar',
      attribute: 'fuelLevel',
      expression: 'adc1 * 0.05',
      type: 'number',
      priority: 1,
      attributes: {'unit': 'liters', 'calibration': 1.05},
    );

    test('TC-CAM-01: Deserializes valid JSON to ComputedAttributeModel', () {
      final json = {
        'id': 10,
        'description': 'Sensor Level Bahan Bakar',
        'attribute': 'fuelLevel',
        'expression': 'adc1 * 0.05',
        'type': 'number',
        'priority': 1,
        'attributes': {'unit': 'liters', 'calibration': 1.05},
      };

      final model = ComputedAttributeModel.fromJson(json);

      expect(model.id, equals(10));
      expect(model.description, equals('Sensor Level Bahan Bakar'));
      expect(model.attribute, equals('fuelLevel'));
      expect(model.expression, equals('adc1 * 0.05'));
      expect(model.type, equals('number'));
      expect(model.priority, equals(1));
      expect(model.attributes['unit'], equals('liters'));
      expect(model.attributes['calibration'], equals(1.05));
    });

    test(
      'TC-CAM-02: Handles empty or missing JSON fields gracefully with defaults',
      () {
        final model = ComputedAttributeModel.fromJson(const {});

        expect(model.id, equals(0));
        expect(model.description, equals(''));
        expect(model.attribute, equals(''));
        expect(model.expression, equals(''));
        expect(model.type, equals('number'));
        expect(model.priority, equals(0));
        expect(model.attributes, isEmpty);
      },
    );

    test('TC-CAM-03: Serializes ComputedAttributeModel to JSON map', () {
      final json = tModel.toJson();

      expect(json['id'], equals(10));
      expect(json['description'], equals('Sensor Level Bahan Bakar'));
      expect(json['attribute'], equals('fuelLevel'));
      expect(json['expression'], equals('adc1 * 0.05'));
      expect(json['type'], equals('number'));
      expect(json['priority'], equals(1));
      expect(json['attributes'], isA<Map>());
      expect(json['attributes']['unit'], equals('liters'));
    });

    test(
      'TC-CAM-04: Serializes without attributes field when attributes map is empty',
      () {
        const model = ComputedAttributeModel(
          id: 1,
          description: 'Status Suhu Mesin',
          attribute: 'tempAlert',
          expression: 'temp > 95 ? "hot" : "normal"',
          type: 'string',
        );

        final json = model.toJson();
        expect(json.containsKey('attributes'), isFalse);
      },
    );

    test(
      'TC-CAM-05: Verifies type helpers isNumber, isString, and isBoolean',
      () {
        const numModel = ComputedAttributeModel(
          id: 1,
          description: 'D',
          attribute: 'a',
          expression: 'e',
          type: 'number',
        );
        expect(numModel.isNumber, isTrue);
        expect(numModel.isString, isFalse);
        expect(numModel.isBoolean, isFalse);

        const strModel = ComputedAttributeModel(
          id: 2,
          description: 'D',
          attribute: 'a',
          expression: 'e',
          type: 'string',
        );
        expect(strModel.isNumber, isFalse);
        expect(strModel.isString, isTrue);
        expect(strModel.isBoolean, isFalse);

        const boolModel = ComputedAttributeModel(
          id: 3,
          description: 'D',
          attribute: 'a',
          expression: 'e',
          type: 'boolean',
        );
        expect(boolModel.isNumber, isFalse);
        expect(boolModel.isString, isFalse);
        expect(boolModel.isBoolean, isTrue);
      },
    );

    test('TC-CAM-06: Enforces unmodifiable attributes map', () {
      final mutableMap = <String, dynamic>{'test': 123};
      final model = ComputedAttributeModel.fromJson({'attributes': mutableMap});

      expect(() => model.attributes['test'] = 999, throwsUnsupportedError);
    });

    test('TC-CAM-07: copyWith returns new instance with updated fields', () {
      final copy = tModel.copyWith(
        description: 'Updated Description',
        priority: 5,
        attributes: {'newKey': 'val'},
      );

      expect(copy.id, equals(10));
      expect(copy.description, equals('Updated Description'));
      expect(copy.attribute, equals('fuelLevel'));
      expect(copy.priority, equals(5));
      expect(copy.attributes['newKey'], equals('val'));
      expect(copy.attributes.containsKey('unit'), isFalse);
    });

    test('TC-CAM-08: Value equality and hashCode check', () {
      final model1 = const ComputedAttributeModel(
        id: 10,
        description: 'Desc',
        attribute: 'attr',
        expression: 'expr',
        type: 'number',
        priority: 0,
        attributes: {'k': 'v'},
      );
      final model2 = const ComputedAttributeModel(
        id: 10,
        description: 'Desc',
        attribute: 'attr',
        expression: 'expr',
        type: 'number',
        priority: 0,
        attributes: {'k': 'v'},
      );
      final model3 = const ComputedAttributeModel(
        id: 11,
        description: 'Desc',
        attribute: 'attr',
        expression: 'expr',
      );

      expect(model1, equals(model2));
      expect(model1.hashCode, equals(model2.hashCode));
      expect(model1, isNot(equals(model3)));
    });
  });

  group('ComputedAttributeTestResultModel Unit Tests', () {
    test('TC-CAM-09: Success factory initializes properly', () {
      final result = ComputedAttributeTestResultModel.success(
        value: 45.8,
        type: 'number',
      );

      expect(result.success, isTrue);
      expect(result.rawValue, equals(45.8));
      expect(result.stringValue, equals('45.8'));
      expect(result.type, equals('number'));
      expect(result.hasValue, isTrue);
      expect(result.error, isNull);
    });

    test(
      'TC-CAM-10: Empty factory initializes with null rawValue and empty stringValue',
      () {
        final result = ComputedAttributeTestResultModel.empty(type: 'boolean');

        expect(result.success, isTrue);
        expect(result.rawValue, isNull);
        expect(result.stringValue, equals(''));
        expect(result.type, equals('boolean'));
        expect(result.hasValue, isFalse);
        expect(result.error, isNull);
      },
    );

    test(
      'TC-CAM-11: Failure factory captures error message and sets success to false',
      () {
        final result = ComputedAttributeTestResultModel.failure(
          error: 'Syntax error: invalid token at line 1',
          type: 'string',
        );

        expect(result.success, isFalse);
        expect(result.rawValue, isNull);
        expect(result.hasValue, isFalse);
        expect(result.error, contains('Syntax error'));
      },
    );

    test('TC-CAM-12: fromResponse and JSON serialization/deserialization', () {
      final res1 = ComputedAttributeTestResultModel.fromResponse(
        true,
        type: 'boolean',
      );
      expect(res1.hasValue, isTrue);
      expect(res1.rawValue, equals(true));
      expect(res1.stringValue, equals('true'));

      final resNull = ComputedAttributeTestResultModel.fromResponse(
        null,
        type: 'number',
      );
      expect(resNull.hasValue, isFalse);

      final json = res1.toJson();
      final fromJson = ComputedAttributeTestResultModel.fromJson(json);
      expect(fromJson, equals(res1));
    });

    test(
      'TC-CAM-13: fromResponse detects JexlException and error strings as failure',
      () {
        final errResult = ComputedAttributeTestResultModel.fromResponse(
          'org.apache.commons.jexl3.JexlException: variable "unknown" undefined',
          type: 'number',
        );

        expect(errResult.success, isFalse);
        expect(errResult.hasValue, isFalse);
        expect(errResult.error, contains('JexlException'));

        final syntaxErr = ComputedAttributeTestResultModel.fromResponse(
          'Failed to evaluate expression: syntax error at line 1',
          type: 'string',
        );
        expect(syntaxErr.success, isFalse);
        expect(syntaxErr.error, contains('syntax error'));
      },
    );

    test(
      'TC-CAM-14: Strict type normalization normalizes unknown types to number',
      () {
        final model = ComputedAttributeModel.fromJson({
          'id': 1,
          'type': 'INVALID_TYPE',
        });
        expect(model.type, equals('number'));
        expect(model.isNumber, isTrue);

        final copy = model.copyWith(type: 'STRING');
        expect(copy.type, equals('string'));
        expect(copy.isString, isTrue);
      },
    );
  });
}
