import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/notifications/domain/helpers/fcm_token_merger.dart';

void main() {
  group('FcmTokenMerger Unit Tests', () {
    const tokenA = 'fcm_token_alpha_11111111111111111111';
    const tokenB = 'fcm_token_bravo_22222222222222222222';
    const tokenC = 'fcm_token_charlie_333333333333333333';
    const tokenD = 'fcm_token_delta_44444444444444444444';
    const legacy22A = '1234567890123456789012'; // 22 chars
    const legacy22B = 'abcdefghijabcdefghijab'; // 22 chars

    test('TC-FTM-01: parseTokens parses null, string, and list safely', () {
      expect(FcmTokenMerger.parseTokens(null), isEmpty);
      expect(FcmTokenMerger.parseTokens(''), isEmpty);
      expect(FcmTokenMerger.parseTokens('  ,, , '), isEmpty);

      // Comma separated string
      final parsedString = FcmTokenMerger.parseTokens(
        '  $tokenA,  $tokenB , $tokenA ',
      );
      expect(parsedString, [tokenA, tokenB]);

      // List of dynamics
      final parsedList = FcmTokenMerger.parseTokens([
        tokenA,
        '  $tokenB  ',
        '',
      ]);
      expect(parsedList, [tokenA, tokenB]);
    });

    test('TC-FTM-02: mergeTokenList appends new token into empty list', () {
      final result = FcmTokenMerger.mergeTokenList([], tokenA);
      expect(result, [tokenA]);
    });

    test('TC-FTM-03: mergeTokenList is idempotent on duplicate tokens', () {
      final initial = [tokenA, tokenB];
      final result = FcmTokenMerger.mergeTokenList(initial, tokenA);
      expect(result, [tokenA, tokenB]);
    });

    test('TC-FTM-04: mergeTokenList enforces maxTokens sliding window', () {
      // Custom max 3
      final initial3 = [tokenA, tokenB, tokenC];
      final result3 = FcmTokenMerger.mergeTokenList(
        initial3,
        tokenD,
        maxTokens: 3,
      );
      expect(result3, [tokenB, tokenC, tokenD]);
      expect(result3.length, 3);

      // Default max 10
      final tokens10 = List.generate(10, (i) => 'token_$i');
      final result10 = FcmTokenMerger.mergeTokenList(tokens10, 'token_new');
      expect(result10.length, 10);
      expect(result10.first, 'token_1');
      expect(result10.last, 'token_new');
    });

    test(
      'TC-FTM-05: mergeTokenList handles 22-char legacy web push tokens',
      () {
        final mixed = [tokenA, legacy22A];
        final result = FcmTokenMerger.mergeTokenList(mixed, legacy22B);

        // 22-char token enforces filtering for 22-char tokens
        expect(result, [legacy22A, legacy22B]);
      },
    );

    test(
      'TC-FTM-06: mergeTokenIntoAttributes preserves existing user attributes',
      () {
        final originalAttributes = <String, dynamic>{
          'speedUnit': 'km/h',
          'soundEvents': 'alarm',
          'theme': 'dark',
          'notificationTokens': tokenA,
        };

        final updated = FcmTokenMerger.mergeTokenIntoAttributes(
          originalAttributes,
          tokenB,
        );

        expect(updated['speedUnit'], 'km/h');
        expect(updated['soundEvents'], 'alarm');
        expect(updated['theme'], 'dark');
        expect(updated['notificationTokens'], '$tokenA,$tokenB');

        // Ensure original map was not mutated
        expect(originalAttributes['notificationTokens'], tokenA);
      },
    );

    test(
      'TC-FTM-07: mergeTokenIntoAttributes works with null initial attributes',
      () {
        final updated = FcmTokenMerger.mergeTokenIntoAttributes(null, tokenA);
        expect(updated, {'notificationTokens': tokenA});
      },
    );

    test(
      'TC-FTM-08: mergeTokenIntoAttributes ignores empty or whitespace token',
      () {
        final initial = <String, dynamic>{'notificationTokens': tokenA};
        final updated = FcmTokenMerger.mergeTokenIntoAttributes(initial, '   ');
        expect(updated['notificationTokens'], tokenA);
      },
    );

    test(
      'TC-FTM-09: removeTokenFromAttributes removes target and keeps others',
      () {
        final initial = <String, dynamic>{
          'speedUnit': 'knots',
          'notificationTokens': '$tokenA,$tokenB,$tokenC',
        };

        final updated = FcmTokenMerger.removeTokenFromAttributes(
          initial,
          tokenB,
        );

        expect(updated['speedUnit'], 'knots');
        expect(updated['notificationTokens'], '$tokenA,$tokenC');
      },
    );

    test(
      'TC-FTM-10: removeTokenFromAttributes strips key when all tokens removed',
      () {
        final initial = <String, dynamic>{
          'soundAlarms': 'sos',
          'notificationTokens': tokenA,
        };

        final updated = FcmTokenMerger.removeTokenFromAttributes(
          initial,
          tokenA,
        );

        expect(updated.containsKey('notificationTokens'), isFalse);
        expect(updated['soundAlarms'], 'sos');
      },
    );
  });
}
