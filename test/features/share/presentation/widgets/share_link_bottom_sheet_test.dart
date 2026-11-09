import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/core/errors/failures.dart';
import 'package:gpsku/features/fleet/data/models/device_model.dart';
import 'package:gpsku/features/share/presentation/providers/share_provider.dart';
import 'package:gpsku/features/share/presentation/widgets/share_link_bottom_sheet.dart';
import 'package:provider/provider.dart';
import '../providers/share_provider_test.dart';

void main() {
  late MockShareRepository mockRepository;
  late ShareProvider shareProvider;

  const tDevice = DeviceModel(
    id: 11,
    name: 'Truk Tronton B 9999 XYZ',
    uniqueId: 'TRONTON-99',
    category: 'truck',
    status: 'online',
  );

  setUp(() {
    mockRepository = MockShareRepository();
    shareProvider = ShareProvider(repository: mockRepository);
  });

  Widget buildTestWidget({Widget? child}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<ShareProvider>.value(
          value: shareProvider,
          child: child ?? const ShareLinkBottomSheet(device: tDevice),
        ),
      ),
    );
  }

  group('ShareLinkBottomSheet Widget Tests', () {
    testWidgets(
      'TC-SLB-01: Renders header with vehicle details, presets, and generate button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Bagikan Pelacakan Publik'), findsOneWidget);
        expect(
          find.text('Truk Tronton B 9999 XYZ • TRONTON-99'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('share_sheet_close_button')),
          findsOneWidget,
        );

        // Preset Chips
        expect(find.byKey(const Key('share_preset_1h')), findsOneWidget);
        expect(find.byKey(const Key('share_preset_6h')), findsOneWidget);
        expect(find.byKey(const Key('share_preset_24h')), findsOneWidget);
        expect(find.byKey(const Key('share_preset_7d')), findsOneWidget);

        // Generate Button
        expect(
          find.byKey(const Key('share_sheet_generate_button')),
          findsOneWidget,
        );
        expect(find.text('Buat Tautan Berbagi'), findsOneWidget);

        // Security Banner
        expect(
          find.textContaining(
            'Penerima tautan dapat melihat posisi langsung armada',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-SLB-02: Tapping duration preset chips updates provider.selectedDuration',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(shareProvider.selectedDuration, const Duration(hours: 24));

        // Tap 1 Jam
        await tester.tap(find.byKey(const Key('share_preset_1h')));
        await tester.pump();
        expect(shareProvider.selectedDuration, const Duration(hours: 1));

        // Tap 7 Hari
        await tester.tap(find.byKey(const Key('share_preset_7d')));
        await tester.pump();
        expect(shareProvider.selectedDuration, const Duration(days: 7));
      },
    );

    testWidgets(
      'TC-SLB-03: Tapping generate button generates link and displays link card',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byKey(const Key('share_sheet_link_card')), findsNothing);

        await tester.tap(find.byKey(const Key('share_sheet_generate_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('share_sheet_link_card')), findsOneWidget);
        expect(find.text('Tautan Publik Aktif'), findsOneWidget);
        expect(find.byKey(const Key('share_sheet_url_text')), findsOneWidget);
        expect(
          find.byKey(const Key('share_sheet_copy_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-SLB-04: Tapping copy button writes URL to Clipboard and displays SnackBar',
      (tester) async {
        // Pre-populate share link
        await shareProvider.generateLink(11);

        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              clipboardText = (methodCall.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(buildTestWidget());

        expect(
          find.byKey(const Key('share_sheet_copy_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('share_sheet_copy_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(clipboardText, contains('https://gpsku.app/?token='));
        expect(
          find.text('Tautan berhasil disalin ke clipboard'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-SLB-05: Displays amber Conflict banner when HTTP 409 Conflict occurs',
      (tester) async {
        mockRepository.failureToReturn = const ConflictFailure(
          'Active link exists',
          statusCode: 409,
        );

        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byKey(const Key('share_sheet_generate_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('share_sheet_conflict_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Tautan berbagi aktif untuk armada ini sudah terdaftar di server',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-SLB-06: Displays red generic error banner when regular failure occurs',
      (tester) async {
        mockRepository.failureToReturn = const ServerFailure(
          'Koneksi server terputus',
          statusCode: 500,
        );

        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byKey(const Key('share_sheet_generate_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byKey(const Key('share_sheet_error_banner')),
          findsOneWidget,
        );
        expect(find.text('Koneksi server terputus'), findsOneWidget);
      },
    );

    testWidgets('TC-SLB-07: Tapping close button pops navigator', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(ShareLinkBottomSheet), findsOneWidget);

      await tester.tap(find.byKey(const Key('share_sheet_close_button')));
      await tester.pump();
    });

    testWidgets(
      'TC-SLB-08: ShareLinkBottomSheet.show modal bottom sheet integration',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<ShareProvider>.value(
                value: shareProvider,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () =>
                        ShareLinkBottomSheet.show(context, device: tDevice),
                    child: const Text('Open Share'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ShareLinkBottomSheet), findsNothing);

        await tester.tap(find.text('Open Share'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ShareLinkBottomSheet), findsOneWidget);
      },
    );
  });
}
