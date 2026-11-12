import 'package:flutter/material.dart';

import 'pages/aziende_page.dart';
import 'pages/frasi_page.dart';
import 'pages/gioco_page.dart';
import 'pages/home_page.dart';
import 'pages/segreto_page.dart';
import 'state/lelas_state.dart';

void main() {
  runApp(const ILelasApp());
}

class ILelasApp extends StatelessWidget {
  const ILelasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD4AF37), // oro, come il lucido del Lelas
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Block Lelas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        fontFamilyFallback: const ['Segoe UI Emoji'],
      ),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  // Contatore anti-spam: 3 tap rapidi sull'ultima tab aprono la pagina segreta.
  DateTime _lastTabTap = DateTime.fromMillisecondsSinceEpoch(0);
  int _tabStreak = 0;

  final _pages = const [
    HomePage(),
    AziendePage(),
    FrasiPage(),
    GiocoPage(),
    SegretoPage(),
  ];

  void _onTap(int i) {
    final now = DateTime.now();
    if (i == _index && now.difference(_lastTabTap).inMilliseconds < 400) {
      _tabStreak++;
      if (_tabStreak >= 3) {
        _tabStreak = 0;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🕵️ Ehi! Le pagine segrete si aprono in altro modo…'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      _tabStreak = 0;
    }
    _lastTabTap = now;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final state = LelasState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              final base = _pages[_index];
              // Easter egg finale: Modalità Lelas → pioggia di emoji su tutto.
              if (state.lelasMode) {
                return Stack(
                  children: [
                    base,
                    const IgnorePointer(child: EmojiRain()),
                  ],
                );
              }
              return base;
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.face), label: 'Il Lelas'),
              NavigationDestination(icon: Icon(Icons.business), label: 'Aziende'),
              NavigationDestination(icon: Icon(Icons.chat_bubble), label: 'Frasi'),
              NavigationDestination(icon: Icon(Icons.apps), label: 'Gioco'),
              NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Segreti'),
            ],
          ),
        );
      },
    );
  }
}

class EmojiRain extends StatelessWidget {
  const EmojiRain({super.key});

  @override
  Widget build(BuildContext context) {
    const emojis = ['🗿', '⌚', '✨', '😎', '🏆'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final random = DateTime.now().millisecondsSinceEpoch;
        final drops = List.generate(24, (i) {
          final h = (i * 7919 + random) % 1000 / 1000;
          return Positioned(
            left: (i * 61 % 100) / 100 * constraints.maxWidth,
            top: h * constraints.maxHeight,
            child: Opacity(
              opacity: 0.35,
              child: Text(
                emojis[i % emojis.length],
                style: const TextStyle(fontSize: 28),
              ),
            ),
          );
        });
        return Stack(children: drops);
      },
    );
  }
}
