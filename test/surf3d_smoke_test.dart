import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prima_prova/pages/surf3d_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test del Lelas Surf 3D: avvia la partita, simula ~15 secondi di
/// corsie, salti e scivolate, riavvia dopo la sconfitta e verifica che non
/// vengano lanciate eccezioni.
void main() {
  testWidgets('Lelas Surf 3D gira senza errori', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Surf3DPage()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('LELAS SURF 3D'), findsOneWidget);

    await tester.tap(find.text('SI PARTE'));
    await tester.pump();

    for (var i = 0; i < 900; i++) {
      if (i % 80 == 0) {
        await tester.flingFrom(
          const Offset(210, 500),
          const Offset(140, 0),
          900,
        );
      } else if (i % 95 == 20) {
        await tester.flingFrom(
          const Offset(210, 500),
          const Offset(0, -160),
          1000,
        );
      } else if (i % 110 == 60) {
        await tester.flingFrom(
          const Offset(210, 500),
          const Offset(0, 160),
          1000,
        );
      }

      if (i % 120 == 0) {
        // Anche la tastiera deve muovere il Lelas.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
      }

      if (i % 30 == 0 && find.text('RIPROVA').evaluate().isNotEmpty) {
        await tester.tap(find.text('RIPROVA'));
        await tester.pump();
      }

      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
  });
}
