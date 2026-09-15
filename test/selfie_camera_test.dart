import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadid_crm/core/camera/selfie_camera.dart';

void main() {
  testWidgets('web camera captures a JPEG from the live video stream', (
    tester,
  ) async {
    Uint8List? photo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                photo = await captureSelfie(context);
              },
              child: const Text('Open camera'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open camera'));
    await tester.pumpAndSettle();
    final capture = find.widgetWithText(FilledButton, 'Suratga olish');
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      if (tester.widget<FilledButton>(capture).onPressed != null) break;
    }
    expect(tester.widget<FilledButton>(capture).onPressed, isNotNull);
    await tester.tap(capture);
    await tester.pumpAndSettle();
    expect(photo, isNotNull);
    expect(photo!.length, greaterThan(1000));
    expect(photo!.take(2), [255, 216]);
    expect(find.text('Dars uchun suratga tushing'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);
}
