import 'dart:math';

import 'package:flutter/material.dart';

import '../state/lelas_state.dart';

/// Finto catalogo di Orologio 2.0, la gioielleria del Lelas.
/// Easter egg:
///  - 5 tap sull'orologio in alto → "Lelas Time" (è sempre ora di lavoro)
///  - 3 tap sul prezzo del primo modello → "Sconto Lelas"
class OrologioPage extends StatefulWidget {
  const OrologioPage({super.key});

  @override
  State<OrologioPage> createState() => _OrologioPageState();
}

class _OrologioPageState extends State<OrologioPage> {
  final Random _random = Random();
  Duration _clockOffset = Duration.zero;
  bool _lelasTime = false;

  static const _watches = [
    ('🗿 Lelas Steel 3000', 'Cassa in cristallo di lucido. Impermeabile allo sguardo altrui.', '€ 1.999,00'),
    ('✨ Crono Calvo Perpetual', 'Non ha lancette: illumina l\'ora.', '€ 2.499,00'),
    ('⌚ Orologio 2.0 Signature', 'Edizione limitata: ne esistono esattamente 2.0.', '€ 3.026,00'),
    ('🛸 Tourbillon Volante', 'Cinturino cucito a mano da mani esperte di ricambio.', '€ 12.500,00'),
  ];

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

  void _onClockTap() {
    final state = LelasState.instance;
    state.incrementClockTaps();
    if (state.clockTaps == 5) {
      setState(() {
        _lelasTime = true;
        _clockOffset = const Duration(hours: 9, minutes: 0);
      });
      _showAchievement('lelas_time');
    } else if (state.clockTaps > 5) {
      // Dopo lo sblocco, ogni tap mette un po' di "ritardo artigianale".
      setState(() {
        _lelasTime = false;
        _clockOffset = Duration(
          minutes: 5 + _random.nextInt(56),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    final now = DateTime.now().add(_clockOffset);
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onClockTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.watch),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _lelasTime ? 'Lelas Time ⌚ $timeLabel' : 'Orologio 2.0',
                  key: ValueKey(timeLabel + (_lelasTime ? 'L' : '')),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: state.unlockAll ? Colors.amber.shade900.withValues(alpha: 0.25) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('🏪', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Benvenuto nella Palestina del Tempo.\n'
                      'Qui il Lelas collauda ogni orologio dandogli una passata di lucido.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, w) in _watches.indexed)
            Card(
              child: ListTile(
                leading: SizedBox(
                  width: 44,
                  child: Center(
                    child: Text(w.$1.split(' ').first, style: const TextStyle(fontSize: 32)),
                  ),
                ),
                title: Text(w.$1.substring(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(w.$2),
                trailing: GestureDetector(
                  onTap: i == 0
                      ? () {
                          state.incrementPriceTaps();
                          if (state.priceTaps == 3) {
                            _showAchievement('sconto_lelas');
                          }
                        }
                      : null,
                  child: AnimatedBuilder(
                    animation: state,
                    builder: (context, _) => Text(
                      i == 0 && state.priceTaps >= 3
                          ? '1 fingerellata di lucido'
                          : w.$3,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: i == 0 && state.priceTaps >= 3
                            ? Colors.greenAccent
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Indizio: l\'orologio in alto non segna l\'ora che credi. 🕐',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
