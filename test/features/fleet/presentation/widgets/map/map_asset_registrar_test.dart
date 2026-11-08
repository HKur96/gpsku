import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/fleet/presentation/widgets/map/map_asset_registrar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapAssetRegistrar - Icon Registry & Generation Tests', () {
    test('TC-MAR-01: Correctly enumerates 7 supported vehicle categories', () {
      expect(MapAssetRegistrar.supportedCategories.length, equals(7));
      expect(
        MapAssetRegistrar.supportedCategories,
        containsAll([
          'default',
          'car',
          'truck',
          'bus',
          'motorcycle',
          'bicycle',
          'person',
        ]),
      );
    });

    test(
      'TC-MAR-02: Correctly enumerates 4 supported status color variants',
      () {
        expect(MapAssetRegistrar.supportedStatusColors.length, equals(4));
        expect(
          MapAssetRegistrar.supportedStatusColors,
          containsAll(['success', 'error', 'neutral', 'info']),
        );
      },
    );

    test(
      'TC-MAR-03: buildIconId generates exact canonical identifier format',
      () {
        expect(
          MapAssetRegistrar.buildIconId('car', 'success'),
          equals('car-success'),
        );
        expect(
          MapAssetRegistrar.buildIconId('truck', 'error'),
          equals('truck-error'),
        );
        expect(
          MapAssetRegistrar.buildIconId('default', 'info'),
          equals('default-info'),
        );
        expect(
          MapAssetRegistrar.buildIconId('bus', 'neutral'),
          equals('bus-neutral'),
        );
      },
    );

    test(
      'TC-MAR-04: buildIconId safely falls back on unknown category or color',
      () {
        expect(
          MapAssetRegistrar.buildIconId('spaceship', 'success'),
          equals('default-success'),
        );
        expect(
          MapAssetRegistrar.buildIconId('car', 'rainbow'),
          equals('car-neutral'),
        );
        expect(
          MapAssetRegistrar.buildIconId('submarine', 'neon'),
          equals('default-neutral'),
        );
      },
    );

    test('TC-MAR-05: Verifies direction icon constant identifier', () {
      expect(MapAssetRegistrar.directionIconId, equals('direction'));
    });

    test(
      'TC-MAR-06: Verifies total fleet icon inventory count equals exactly 29 assets',
      () {
        final allIds = <String>{};
        for (final cat in MapAssetRegistrar.supportedCategories) {
          for (final col in MapAssetRegistrar.supportedStatusColors) {
            allIds.add(MapAssetRegistrar.buildIconId(cat, col));
          }
        }
        allIds.add(MapAssetRegistrar.directionIconId);

        // 7 categories * 4 colors + 1 direction pointer = 29 unique assets
        expect(allIds.length, equals(29));
      },
    );

    test(
      'TC-MAR-07: Rasterizes vehicle marker icon to valid PNG format with magic signature',
      () async {
        final bytes = await MapAssetRegistrar.generateCategoryMarkerBytes(
          category: 'car',
          statusColor: 'success',
          pixelRatio: 2.0,
        );

        expect(bytes.isNotEmpty, isTrue);
        // Standard PNG Magic signature: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
        expect(bytes[0], equals(0x89));
        expect(bytes[1], equals(0x50)); // 'P'
        expect(bytes[2], equals(0x4E)); // 'N'
        expect(bytes[3], equals(0x47)); // 'G'
      },
    );

    test('TC-MAR-08: Rasterizes direction arrow to valid PNG format', () async {
      final bytes = await MapAssetRegistrar.generateDirectionArrowBytes(
        pixelRatio: 2.0,
      );

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50));
      expect(bytes[2], equals(0x4E));
      expect(bytes[3], equals(0x47));
    });

    test(
      'TC-MAR-09: Pixel ratio scaling produces larger rasterized output',
      () async {
        final bytes1x = await MapAssetRegistrar.generateCategoryMarkerBytes(
          category: 'truck',
          statusColor: 'error',
          pixelRatio: 1.0,
        );
        final bytes3x = await MapAssetRegistrar.generateCategoryMarkerBytes(
          category: 'truck',
          statusColor: 'error',
          pixelRatio: 3.0,
        );

        expect(bytes1x.isNotEmpty, isTrue);
        expect(bytes3x.isNotEmpty, isTrue);
        // 3x raster contains significantly more pixel data than 1x raster
        expect(bytes3x.length, greaterThan(bytes1x.length));
      },
    );

    test(
      'TC-MAR-10: Successfully rasterizes all 28 category/color combinations without errors',
      () async {
        for (final category in MapAssetRegistrar.supportedCategories) {
          for (final color in MapAssetRegistrar.supportedStatusColors) {
            final bytes = await MapAssetRegistrar.generateCategoryMarkerBytes(
              category: category,
              statusColor: color,
              pixelRatio: 1.5,
            );
            expect(
              bytes.isNotEmpty,
              isTrue,
              reason: 'Failed for $category-$color',
            );
            expect(bytes[0], equals(0x89));
          }
        }
      },
    );
  });
}
