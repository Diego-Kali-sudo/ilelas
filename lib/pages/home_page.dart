import 'package:flutter/material.dart';

import '../state/lelas_state.dart';
import '../widgets/lelas_avatar.dart';

/// Home: profilo del Lelas + mini-gioco "appa la testa".
/// Easter egg:
///  - 1 tocco   → achievement "Primo Lucido"
///  - 10 tocchi → "Pulizia Deluxe" (scoppio di brillantini)
///  - 25 tocchi → "Lucentezza Leggendaria"
///  - 50 tocchi → "Testa Volante" (la testa decolla)
///  - long press sul badge → campo codice segreto
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _flight = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  bool _flying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAchievement(BuildContext context, String id) {
    final state = LelasState.instance;
    if (!state.unlock(id)) return;
    final info = LelasState.allAchievements[id]!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade700,
        content: Text('${info.$1}\n${info.$2}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onHeadTap() {
    final state = LelasState.instance;
    state.incrementHeadTaps();
    switch (state.headTaps) {
      case 1:
        _showAchievement(context, 'primo_tocco');
      case 10:
        _showAchievement(context, 'pulizia_deluxe');
        _burst();
      case 25:
        _showAchievement(context, 'lucentezza_leggendaria');
      case 50:
        _showAchievement(context, 'testa_volante');
        setState(() => _flying = true);
        _controller.forward(from: 0);
      case >= 50 when state.headTaps % 50 == 0:
        _controller.forward(from: 0);
    }
  }

  void _burst() {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Stack(
          children: [
            for (var i = 0; i < 12; i++)
              Positioned(
                left: MediaQuery.of(context).size.width * (0.15 + (i * 37 % 70) / 100),
                top: MediaQuery.of(context).size.height * 0.28,
                child: const Text('✨', style: TextStyle(fontSize: 30)),
              ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 900), () => entry?.remove());
  }

  void _openSecretCode() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Codice segreto'),
        content: TextField(
          controller: controller,
          obscureText: false,
          decoration: const InputDecoration(
            hintText: 'Scrivi qui… (indizio: guarda in alto a destra della Palestra di Lelas)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim().toLowerCase().replaceAll(' ', '');
              final state = LelasState.instance;
              if (code == 'orologio2.0' || code == 'orologio20') {
                state.setUnlockAll();
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.amber,
                    content: Text('🏆 Dipendente del Mese! Tutto sbloccato.'),
                  ),
                );
              } else if (code == 'lelas') {
                state.setLelasMode();
                Navigator.pop(context);
              } else if (code.isNotEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('❌ Codice sbagliato. Lelas ti guarda con disprezzo.')),
                );
              }
            },
            child: const Text('Prova'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _openSecretCode,
          child: const Text('ILelas 🗿'),
        ),
        actions: [
          IconButton(
            tooltip: 'Codice segreto (long-press anche qui)',
            onPressed: _openSecretCode,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _flight,
                builder: (context, child) {
                  final dy = -_flight.value * 420;
                  final scale = 1.0 - _flight.value * 0.6;
                  return Transform.translate(
                    offset: Offset(0, _flying ? dy : 0),
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: LelasAvatar(
                  onTap: _onHeadTap,
                  onLongPress: () {
                    state.setUnlockAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🏆 Hai trovato il gesto segreto! Tutto sbloccato.')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Emanuele "Illelas" Santini',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Maestro orologiaio @ Orologio 2.0',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.primary,
                    ),
              ),
              const SizedBox(height: 16),
              // Livello di lucido
              AnimatedBuilder(
                animation: state,
                builder: (context, _) {
                  final level = (state.headTaps / 50).clamp(0.0, 1.0);
                  return Column(
                    children: [
                      Text(
                        state.unlockAll
                            ? 'Modalità Dipendente dell\'Anno attiva 🏆'
                            : 'Livello di lucido: ${(level * 100).round()}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 240,
                        child: LinearProgressIndicator(
                          value: level,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tocca la testa per farla brillare. Long-press per… boh, prova. 😏',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
