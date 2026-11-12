import 'package:flutter/material.dart';

import '../state/lelas_state.dart';

/// Pagina segreta: elenco achievement + codice + reset.
/// Easter egg: il codice è "orologio2.0" (modalità Dipendente del Mese)
/// oppure "lelas" (Lelas Mode: pioggia di emoji).
class SegretoPage extends StatelessWidget {
  const SegretoPage({super.key});

  void _checkCode(BuildContext context, String raw) {
    final code = raw.trim().toLowerCase().replaceAll(' ', '');
    final state = LelasState.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (code == 'orologio2.0' || code == 'orologio20') {
      state.setUnlockAll();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          content: Text('🏆 Dipendente del Mese! Tema dorato sbloccato.'),
        ),
      );
    } else if (code == 'lelas') {
      state.setLelasMode();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          content: Text('🗿 LELAS MODE ATTIVATA!'),
        ),
      );
    } else if (code.isNotEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('❌ Codice errato. Indizi: la pagina Orologio e la Home.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    final controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Archivio Segreto 🔐')),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final unlocked = state.achievements.length;
          final total = LelasState.allAchievements.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Progresso segreto: $unlocked / $total'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: unlocked / total,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in LelasState.allAchievements.entries)
                Card(
                  color: state.achievements.contains(entry.key)
                      ? Colors.amber.withValues(alpha: 0.15)
                      : null,
                  child: ListTile(
                    leading: SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          state.achievements.contains(entry.key) ? entry.value.$1 : '🔒',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    title: Text(
                      state.achievements.contains(entry.key)
                          ? entry.value.$1.substring(2)
                          : 'Achievement bloccato',
                    ),
                    subtitle: state.achievements.contains(entry.key)
                        ? Text(entry.value.$2)
                        : const Text('Continua a esplorare…'),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Codice segreto',
                  hintText: 'Psst… due codici esistono. Uno riguarda il lavoro.',
                ),
                onSubmitted: (value) => _checkCode(context, value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _checkCode(context, controller.text),
                child: const Text('Prova il codice'),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset?'),
                      content: const Text('Cancellare tutti i progressi e gli achievement?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('No'),
                        ),
                        FilledButton(
                          onPressed: () {
                            LelasState.instance.resetAll();
                            Navigator.pop(context);
                          },
                          child: const Text('Sì, ripartiamo'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset progressi'),
              ),
            ],
          );
        },
      ),
    );
  }
}
