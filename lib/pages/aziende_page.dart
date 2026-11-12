import 'package:flutter/material.dart';

import '../state/lelas_state.dart';

/// Finto "quartier generale" delle aziende del Lelas a Firenze.
/// Easter egg:
///  - 5 tap sul titolo → "Lelas in Riunione" (è sempre ora di riunione)
///  - 3 tap sulla "valutazione" del primo modello → "Valutazione Rivista"
class AziendePage extends StatefulWidget {
  const AziendePage({super.key});

  @override
  State<AziendePage> createState() => _AziendePageState();
}

class _AziendePageState extends State<AziendePage> {
  int _clockTaps = 0;
  int _priceTaps = 0;
  bool _lelasMeeting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LelasState.instance.unlock('ceo_onorario');
    });
  }

  static const _companies = [
    ('💼 Montefalchi SRL', 'Società di gestione e sviluppo immobiliare e commerciale. Nata a Firenze.', 'Valutazione: € 1.999.000'),
    ('🤝 Giocolare Società Coop', 'Cooperativa di servizi e attività ricreative per il territorio.', 'Valutazione: € 2.499.000'),
    ('🌱 Genga APS', 'Associazione di promozione sociale, cultura e aggregazione.', 'Valutazione: € 3.026.000'),
    ('📦 La Scatola Galluzzo', 'Attività culturale e di aggregazione nel quartiere Galluzzo.', 'Valutazione: € 12.500.000'),
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

  void _onTitleTap() {
    setState(() => _clockTaps++);
    if (_clockTaps == 5) {
      setState(() => _lelasMeeting = true);
      _showAchievement('riunione_lelas');
    } else if (_clockTaps > 5) {
      setState(() => _lelasMeeting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _lelasMeeting ? 'Lelas in Riunione 💼' : 'Aziende del Lelas',
                  key: ValueKey(_lelasMeeting),
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
                  const Text('🏛️', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Benvenuto nel quartier generale del Lelas.\n'
                      'Qui il CEO collauda ogni decisione con una passata di lucido.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, w) in _companies.indexed)
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
                          setState(() => _priceTaps++);
                          if (_priceTaps == 3) {
                            _showAchievement('valutazione_rivista');
                          }
                        }
                      : null,
                  child: Text(
                    i == 0 && _priceTaps >= 3
                        ? 'Valutazione rivista dal Lelas'
                        : w.$3,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i == 0 && _priceTaps >= 3
                          ? Colors.greenAccent
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Indizio: il titolo in alto non dice sempre la stessa cosa. 💼',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
