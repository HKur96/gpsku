import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpsku/features/commands/presentation/widgets/slide_to_confirm_widget.dart';

void main() {
  group('SlideToConfirmWidget Unit & Interaction Tests', () {
    testWidgets(
      'TC-STC-01: Initial state renders track, thumb, and label at 0% progress',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SlideToConfirmWidget(label: 'Geser untuk Konfirmasi'),
                ),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('slide_to_confirm_track')), findsOneWidget);
        expect(find.byKey(const Key('slide_to_confirm_thumb')), findsOneWidget);
        expect(find.byKey(const Key('slide_to_confirm_label')), findsOneWidget);
        expect(find.text('Geser untuk Konfirmasi'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-STC-02: Dragging below 90% threshold snaps back and does NOT trigger callback',
      (tester) async {
        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SlideToConfirmWidget(
                    label: 'Geser untuk Konfirmasi',
                    onConfirmed: () => confirmed = true,
                  ),
                ),
              ),
            ),
          ),
        );

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));

        // Total track = 300, thumb = 46 (54 - 8), maxDrag = 300 - 46 - 8 = 246.
        // 90% of maxDrag = 221.4. Dragging 100 pixels is ~40% (well below 90%).
        await tester.drag(thumb, const Offset(100, 0));
        await tester.pumpAndSettle();

        expect(confirmed, isFalse);
        // Thumb should reset back to initial offset
        expect(find.text('Geser untuk Konfirmasi'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-STC-03: Dragging >= 90% threshold triggers onConfirmed callback and locks confirmed',
      (tester) async {
        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SlideToConfirmWidget(
                    label: 'Geser untuk Matikan Mesin',
                    confirmedLabel: 'Terkonfirmasi Sukses',
                    onConfirmed: () => confirmed = true,
                  ),
                ),
              ),
            ),
          ),
        );

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));

        // Drag 260 pixels (exceeds maxDrag 246, clamped to 100%)
        await tester.drag(thumb, const Offset(260, 0));
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
        expect(find.text('Terkonfirmasi Sukses'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-STC-04: When enabled=false, gestures are ignored and locked label is displayed',
      (tester) async {
        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SlideToConfirmWidget(
                    enabled: false,
                    onConfirmed: () => confirmed = true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Terkunci / Nonaktif'), findsOneWidget);

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(260, 0));
        await tester.pumpAndSettle();

        expect(confirmed, isFalse);
      },
    );

    testWidgets(
      'TC-STC-05: When isLoading=true, displays CircularProgressIndicator and disables drag',
      (tester) async {
        bool confirmed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SlideToConfirmWidget(
                    isLoading: true,
                    onConfirmed: () => confirmed = true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('slide_to_confirm_loading')),
          findsOneWidget,
        );

        final thumb = find.byKey(const Key('slide_to_confirm_thumb'));
        await tester.drag(thumb, const Offset(260, 0));
        await tester.pump(const Duration(milliseconds: 100));

        expect(confirmed, isFalse);
      },
    );
  });
}
