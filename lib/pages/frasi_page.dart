import 'package:flutter/material.dart';

import '../state/lelas_state.dart';

/// Generatore di frasi del Lelas.
/// Easter egg: alla 7ª frase generata arriva quella segreta
/// ("Frase Segreta") e appare un pulsante "Vero finale".
class FrasiPage extends StatefulWidget {
  const FrasiPage({super.key});

  @override
  State<FrasiPage> createState() => _FrasiPageState();
}

class _FrasiPageState extends State<FrasiPage> {
  static const _frasi = [
    "«Non è calvo, è aerodinamico.»",
    "«Ogni azienda ha un'anima. La mia l'ho trovata a Firenze.»",
    "«Il lucido non si compra, si sente.»",
    "«Prima il sogno, poi la SRL.»",
    "«Se il tempo vola, io ho la licenza di pilotaggio.»",
    "«Un Lelas, quattro aziende, zero capelli... zero pensieri.»",
    "«La cura del dettaglio inizia dalla testa.»",
  ];

  static const _fraseSegreta =
      '«Il segreto? Tratta ogni cliente come un amico e ogni azienda '
      'come se fosse la prima che hai fondato.» — Lelas, veramente.';

  int _index = 0;

  void _showAchievement(String id) {
    final state = LelasState.instance;
    if (!state.unlock(id)) return;
    final info = LelasState.allAchievements[id]!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade700,
        content: Text('${info.$1}\n${info.$2}'),
      ),
    );
  }

  void _next() {
    final state = LelasState.instance;
    state.incrementQuoteTaps();
    setState(() {
      _index = (state.quoteTaps - 1) % _frasi.length;
      if (state.quoteTaps == 7) {
        _showAchievement('frase_segreta');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    final showSecret = state.quoteTaps >= 7;
    return Scaffold(
      appBar: AppBar(title: const Text('Le frasi del Lelas 💬')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    state.quoteTaps == 7 ? _fraseSegreta : _frasi[_index],
                    key: ValueKey(state.quoteTaps),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.casino),
              label: Text(showSecret ? 'Un\'altra frase' : 'Frase n.${state.quoteTaps + 1}'),
            ),
            const SizedBox(height: 8),
            Text(
              'Dopo 7 frasi… qualcosa cambia. 🤫',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (showSecret) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗿 "Appunto." — Lelas approva il tuo gusto.'),
                    ),
                  );
                },
                child: const Text('🗿 Saluta il Lelas'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
