import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prima_prova/pages/surf_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test del Lelas Surf: avvia la partita e simula 15 secondi di gioco
/// con salti e scivolate, verificando che non vengano lanciate eccezioni.
void main() {
  testWidgets('Lelas Surf gira senza errori', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SurfPage()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('SI PARTE'));
    await tester.pump();

    for (var i = 0; i < 900; i++) {
      if (i % 55 == 0) {
        await tester.tapAt(const Offset(210, 560));
      } else if (i % 133 == 0) {
        await tester.flingFrom(
          const Offset(210, 400),
          const Offset(0, 120),
          1200,
        );
      }
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
  });
}
