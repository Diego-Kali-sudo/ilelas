// Smoke test di base per l'app ILelas.
import 'package:flutter_test/flutter_test.dart';

import 'package:prima_prova/main.dart';
import 'package:prima_prova/state/lelas_state.dart';

void main() {
  testWidgets("L'app si avvia e mostra la Home del Lelas", (WidgetTester tester) async {
    LelasState.instance.resetAll();
    await tester.pumpWidget(const ILelasApp());
    await tester.pumpAndSettle();

    expect(find.text('ILelas 🗿'), findsOneWidget);
    expect(find.text('Emanuele "Illelas" Santini'), findsOneWidget);
    expect(find.text('Maestro orologiaio @ Orologio 2.0'), findsOneWidget);
  });
}
