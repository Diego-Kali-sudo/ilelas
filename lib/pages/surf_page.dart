import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/lelas_state.dart';
import '../widgets/lelas_avatar.dart';

/// Palette condivisa con il resto dell'app.
const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFFFE28A);

enum _Phase { ready, running, dead }

/// "Lelas Surf": runner 2D a scorrimento orizzontale.
///
/// Il Lelas corre tra i monumenti di Firenze, salta i pacchi di Genga APS e
/// scivola sotto i cartelli sospesi di Giocolare. Tutto disegnato a mano con
/// un solo [CustomPainter]: niente asset pesanti, gira fluido anche su Safari.
class SurfPage extends StatefulWidget {
  const SurfPage({super.key});

  @override
  State<SurfPage> createState() => _SurfPageState();
}

class _SurfPageState extends State<SurfPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final FocusNode _focus = FocusNode();
  final _World _world = _World();

  /// Tick di repaint: il painter si ridisegna senza rebuild di widget.
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final ValueNotifier<int> _score = ValueNotifier<int>(0);
  final ValueNotifier<int> _coins = ValueNotifier<int>(0);

  _Phase _phase = _Phase.ready;
  Size _size = Size.zero;
  Duration _lastElapsed = Duration.zero;
  int _best = 0;
  bool _newRecord = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _loadBest();
    _loadAvatar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    _score.dispose();
    _coins.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastElapsed = Duration.zero;
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  // ── Caricamento ──────────────────────────────────────────────────────────

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('surf_lelas_best') ?? 0;
    if (mounted) setState(() => _best = saved);
  }

  Future<void> _saveBest(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('surf_lelas_best', value);
  }

  /// Decodifica la foto del Lelas una volta sola: il painter la riusa.
  Future<void> _loadAvatar() async {
    try {
      final data = await rootBundle.load(LelasAvatar.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 256,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      _world.avatar = frame.image;
      _repaint.value++;
    } catch (_) {
      // Senza foto il gioco funziona lo stesso (faccina disegnata).
    }
  }

  // ── Game loop ────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.0, 0.05)
        .toDouble();
    _lastElapsed = elapsed;
    if (_size.isEmpty) return;

    _world.update(dt, running: _phase == _Phase.running);

    if (_score.value != _world.score) _score.value = _world.score;
    if (_coins.value != _world.coins) _coins.value = _world.coins;

    if (_world.dead && _phase == _Phase.running) {
      _die();
    }
    _repaint.value++;
  }

  void _start() {
    if (_phase == _Phase.running) return;
    _lastElapsed = Duration.zero;
    _newRecord = false;
    setState(() => _phase = _Phase.running);
    _world.start();
    _focus.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _restart() {
    _world.start();
    _score.value = 0;
    _coins.value = 0;
    _lastElapsed = Duration.zero;
    _newRecord = false;
    setState(() => _phase = _Phase.running);
    _focus.requestFocus();
  }

  void _die() {
    _phase = _Phase.dead;
    HapticFeedback.heavyImpact();
    final score = _world.score;
    if (score > _best) {
      _newRecord = true;
      _best = score;
      _saveBest(score);
    }
    setState(() {});
    if (score >= 300) _unlock('surfista_del_duomo');
    if (score >= 1000) _unlock('ceo_maratoneta');
    if (score >= 2500) _unlock('re_del_surf');
  }

  void _unlock(String id) {
    if (!LelasState.instance.unlock(id)) return;
    final info = LelasState.allAchievements[id]!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade700,
        content: Text('${info.$1}\n${info.$2}'),
      ),
    );
  }

  // ── Input ────────────────────────────────────────────────────────────────

  void _jump() {
    switch (_phase) {
      case _Phase.ready:
        _start();
      case _Phase.running:
        if (_world.jump()) HapticFeedback.lightImpact();
      case _Phase.dead:
        break;
    }
  }

  void _slide() {
    if (_phase != _Phase.running) return;
    if (_world.slide()) HapticFeedback.lightImpact();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW) {
      _jump();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      _slide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lelas Surf 🏃'),
        actions: [
          IconButton(
            tooltip: 'Ricomincia',
            onPressed: _phase == _Phase.dead ? _restart : null,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);
          _world.resize(_size);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _focus.requestFocus();
              if (_phase != _Phase.dead) _jump();
            },
            onVerticalDragUpdate: (d) {
              if (d.delta.dy > 6) _slide();
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SurfPainter(_world, _repaint),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(child: _hud(context)),
                  ),
                  if (_phase == _Phase.ready)
                    Positioned.fill(child: _readyOverlay(context)),
                  if (_phase == _Phase.dead)
                    Positioned.fill(child: _deadOverlay(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hud(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _score,
          builder: (context, value, _) => _hudPill(
            icon: Icons.speed,
            text: '$value',
            color: _kGold,
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: _coins,
          builder: (context, value, _) => _hudPill(
            icon: Icons.workspace_premium,
            text: '$value',
            color: _kGoldLight,
          ),
        ),
        const Spacer(),
        _hudPill(
          icon: Icons.emoji_events,
          text: '$_best',
          color: Colors.white70,
        ),
      ],
    );
  }

  Widget _hudPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.30),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LELAS SURF',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: _kGold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Corri per Firenze. Non fermarti in riunione.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 26),
              _hint(Icons.touch_app, 'Tocca / Spazio per saltare'),
              const SizedBox(height: 8),
              _hint(Icons.swipe_down, 'Trascina giù / ↓ per scivolare'),
              const SizedBox(height: 8),
              _hint(Icons.toll, 'Raccogli i contratti d\'oro'),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('SI PARTE'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _deadOverlay(BuildContext context) {
    final isRecord = _newRecord;
    return Container(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _world.deathQuote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statBox('PUNTI', '${_world.score}'),
                  const SizedBox(width: 14),
                  _statBox('CONTRATTI', '${_world.coins}'),
                  const SizedBox(width: 14),
                  _statBox('RECORD', '$_best'),
                ],
              ),
              if (isRecord) ...[
                const SizedBox(height: 16),
                const Text(
                  '🏆 NUOVO RECORD!',
                  style: TextStyle(
                    color: _kGoldLight,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: const Text('RIPROVA'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Torna al Block Lelas'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kGold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Motore di gioco
// ───────────────────────────────────────────────────────────────────────────

enum _ObstacleType { crate, air }

class _Obstacle {
  _Obstacle({
    required this.x,
    required this.type,
    required this.wFactor,
    required this.hFactor,
    required this.seed,
  });

  double x;
  final _ObstacleType type;
  final double wFactor; // larghezza in frazioni di altezza schermo
  final double hFactor; // altezza / spessore
  final int seed;

  static _Obstacle crate(double x, double wFactor, double hFactor, int seed) =>
      _Obstacle(
        x: x,
        type: _ObstacleType.crate,
        wFactor: wFactor,
        hFactor: hFactor,
        seed: seed,
      );

  static _Obstacle air(double x, int seed) => _Obstacle(
        x: x,
        type: _ObstacleType.air,
        wFactor: 0.105,
        hFactor: 0.135,
        seed: seed,
      );

  /// Rettangolo di collisione/disegno, in coordinate schermo.
  Rect rect(_World world) {
    final hh = world.h;
    if (type == _ObstacleType.air) {
      return Rect.fromLTWH(
        x,
        world.groundY - hh * 0.225,
        wFactor * hh,
        hFactor * hh,
      );
    }
    return Rect.fromLTWH(
      x,
      world.groundY - hFactor * hh,
      wFactor * hh,
      hFactor * hh,
    );
  }
}

class _Coin {
  _Coin({required this.x, required this.height, required this.phase});
  double x;
  final double height; // altezza dal suolo
  final double phase; // sfasamento della rotazione
  bool taken = false;
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
  });

  double x, y, vx, vy;
  double life;
  late final double maxLife = life;
  final double size;
  final Color color;
}

class _Building {
  _Building(this.x, this.w, this.h, this.kind);
  final double x; // unità del tile (900)
  final double w;
  final double h; // 0..1 frazione dell'altezza massima
  final int kind; // 0 palazzo, 1 duomo, 2 campanile
}

class _World {
  final Random _rng = Random();
  ui.Image? avatar;

  double w = 0;
  double h = 0;
  double groundY = 0;
  double t = 0;

  // Giocatore
  double y = 0; // altezza dal suolo
  double vy = 0;
  bool onGround = true;
  int jumps = 0;
  bool sliding = false;
  double slideTimer = 0;
  double runCycle = 0;

  // Mondo
  double distance = 0;
  double speed = 0;
  int score = 0;
  int coins = 0;
  bool dead = false;

  final List<_Obstacle> obstacles = [];
  final List<_Coin> coinList = [];
  final List<_Particle> particles = [];

  double _spawnIn = 0;
  double _coinIn = 0;
  double _shake = 0;
  double _flash = 0;
  double _bgFar = 0;
  double _bgMid = 0;
  double _bgGround = 0;

  List<_Building> _far = [];
  List<_Building> _mid = [];
  List<Offset> _stars = [];

  ui.Gradient? _skyGradient;
  Size? _gradientSize;

  String deathQuote = '';

  static const List<String> _quotes = [
    '"Anche il CEO più veloce trova un ostacolo." — Lelas',
    '"Il Lelas non cade: prende tempo per la prossima riunione." — Lelas',
    '"A Firenze si corre, ma con stile." — Lelas',
    '"Il fatturato non si ferma mai. Nemmeno tu." — Lelas',
    '"Rallentare è un lusso che non ci possiamo permettere." — Lelas',
  ];

  // ── Setup ────────────────────────────────────────────────────────────────

  void resize(Size s) {
    final changed = s.width != w || s.height != h;
    w = s.width;
    h = s.height;
    groundY = h * 0.82;
    if (changed || _far.isEmpty) {
      _buildSkyline();
      _skyGradient = null;
    }
  }

  void _buildSkyline() {
    final stars = Random(5);
    _stars = List.generate(
      55,
      (_) => Offset(stars.nextDouble(), stars.nextDouble() * 0.55),
    );

    final far = Random(11);
    _far = [];
    double x = 0;
    while (x < 900) {
      final bw = 24 + far.nextDouble() * 42;
      _far.add(_Building(x, bw, 0.22 + far.nextDouble() * 0.42, 0));
      x += bw + 5 + far.nextDouble() * 9;
    }
    // Duomo di Firenze tra i palazzi.
    _far.insert(_far.length ~/ 2, _Building(420, 96, 0.88, 1));
    // Campanile di Giotto poco più avanti.
    _far.add(_Building(700, 26, 0.98, 2));

    final mid = Random(23);
    _mid = [];
    x = 0;
    while (x < 900) {
      final bw = 30 + mid.nextDouble() * 54;
      _mid.add(_Building(x, bw, 0.18 + mid.nextDouble() * 0.30, 0));
      x += bw + 8 + mid.nextDouble() * 14;
    }
  }

  void start() {
    dead = false;
    y = 0;
    vy = 0;
    onGround = true;
    jumps = 0;
    sliding = false;
    slideTimer = 0;
    distance = 0;
    speed = h * 0.40;
    score = 0;
    coins = 0;
    obstacles.clear();
    coinList.clear();
    particles.clear();
    _spawnIn = 1.5;
    _coinIn = 1.2;
    _shake = 0;
    _flash = 0;
  }

  double get difficulty => min(1.0, distance / (h * 22));

  // ── Input ────────────────────────────────────────────────────────────────

  bool jump() {
    if (dead) return false;
    if (onGround) {
      vy = h * 1.25;
      onGround = false;
      jumps = 1;
      _puff(6);
      return true;
    }
    if (jumps < 2) {
      vy = h * 1.02;
      jumps = 2;
      _puff(10);
      return true;
    }
    return false;
  }

  bool slide() {
    if (dead) return false;
    if (!onGround) {
      // Scivolata a mezz'aria = caduta rapida, come nei runner veri.
      vy = -h * 1.4;
      return true;
    }
    sliding = true;
    slideTimer = 0.55;
    _puff(5);
    return true;
  }

  // ── Update ───────────────────────────────────────────────────────────────

  void update(double dt, {required bool running}) {
    t += dt;

    final idle = !running;
    final base = h * 0.40;
    final maxSpeed = h * 0.95;

    if (idle) {
      speed = h * 0.22;
      runCycle += dt * 9;
    } else {
      speed = base + (maxSpeed - base) * difficulty;
      distance += speed * dt;
      runCycle += dt * (6 + speed / (h * 0.9));
    }

    // Parallasse
    _bgFar += speed * dt * 0.10;
    _bgMid += speed * dt * 0.26;
    _bgGround += speed * dt;

    if (running) {
      _updatePhysics(dt);
      _updateSpawning(dt);
      _updateEntities(dt);
      score = (distance / (h * 0.016)).floor() + coins * 5;
    } else {
      _updatePhysics(dt);
    }

    _updateParticles(dt);

    if (_shake > 0) _shake = max(0.0, _shake - dt * 42);
    if (_flash > 0) _flash = max(0.0, _flash - dt * 2.2);
  }

  void _updatePhysics(double dt) {
    if (sliding) {
      slideTimer -= dt;
      if (slideTimer <= 0) sliding = false;
    }
    if (!onGround) {
      vy -= h * 3.15 * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
        onGround = true;
        jumps = 0;
        _puff(4);
      }
    }
  }

  void _updateSpawning(double dt) {
    if (dead) return;

    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawnPattern();
      final gap = 1.05 - 0.38 * difficulty + _rng.nextDouble() * 0.32;
      _spawnIn = gap;
    }

    _coinIn -= dt;
    if (_coinIn <= 0) {
      _spawnCoinArc();
      _coinIn = 1.3 + _rng.nextDouble() * 1.7;
    }
  }

  void _spawnPattern() {
    final d = difficulty;
    final x0 = w + h * 0.06;
    final r = _rng.nextDouble();

    if (d > 0.18 && r < 0.20) {
      obstacles.add(_Obstacle.air(x0, _rng.nextInt(999)));
      return;
    }
    if (d > 0.32 && r < 0.42) {
      final ow = h * 0.070;
      obstacles.add(_Obstacle.crate(
        x0,
        ow / h,
        0.055 + _rng.nextDouble() * 0.030,
        _rng.nextInt(999),
      ));
      obstacles.add(_Obstacle.crate(
        x0 + ow * 1.85,
        ow / h,
        0.055 + _rng.nextDouble() * 0.030,
        _rng.nextInt(999),
      ));
      return;
    }
    obstacles.add(_Obstacle.crate(
      x0,
      0.055 + _rng.nextDouble() * 0.030,
      0.050 + _rng.nextDouble() * 0.055,
      _rng.nextInt(999),
    ));
  }

  void _spawnCoinArc() {
    final n = 3 + _rng.nextInt(3);
    final startX = w + h * 0.05;
    final baseH = h * (0.14 + _rng.nextDouble() * 0.10);
    final apex = _rng.nextBool() ? h * 0.10 : 0.0;
    final spacing = h * 0.060;
    for (var i = 0; i < n; i++) {
      final p = i / (n - 1);
      final arc = sin(p * pi) * apex;
      coinList.add(_Coin(
        x: startX + i * spacing,
        height: baseH + arc,
        phase: i * 1.35 + _rng.nextDouble() * 0.6,
      ));
    }
  }

  void _updateEntities(double dt) {
    final dx = speed * dt;

    for (final o in obstacles) {
      o.x -= dx;
    }
    obstacles.removeWhere((o) => o.x < -h * 0.35);

    final pc = playerCenter;
    for (final c in coinList) {
      c.x -= dx;
      if (c.taken) continue;
      final cy = groundY - c.height;
      final r = h * 0.034;
      if ((c.x - pc.dx).abs() < r + w * 0.03 &&
          (cy - pc.dy).abs() < r + h * 0.05) {
        c.taken = true;
        coins++;
        HapticFeedback.selectionClick();
        _burst(c.x, cy);
      }
    }
    coinList.removeWhere((c) => c.x < -h * 0.2 || c.taken);

    // Collisioni
    final pr = playerRect;
    for (final o in obstacles) {
      if (o.rect(this).overlaps(pr)) {
        _die();
        return;
      }
    }
  }

  void _die() {
    if (dead) return;
    dead = true;
    _shake = 14;
    _flash = 1;
    deathQuote = _quotes[_rng.nextInt(_quotes.length)];
    _puff(24);
  }

  // ── Geometria ────────────────────────────────────────────────────────────

  double get playerX => w * 0.24;
  double get playerHeight => sliding ? h * 0.062 : h * 0.115;
  double get playerWidth => h * 0.072;

  Rect get playerRect {
    final hh = playerHeight;
    final rect = Rect.fromLTWH(
      playerX - playerWidth * 0.42,
      groundY - y - hh,
      playerWidth * 0.84,
      hh,
    );
    // Un filo di tolleranza: i runner devono essere generosi.
    return rect.deflate(h * 0.006);
  }

  Offset get playerCenter => Offset(
        playerX,
        groundY - y - playerHeight * 0.55,
      );

  // ── Particelle ───────────────────────────────────────────────────────────

  void _puff(int n) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi;
      final s = h * (0.06 + _rng.nextDouble() * 0.18);
      particles.add(_Particle(
        x: playerX,
        y: groundY - y - h * 0.008,
        vx: cos(a) * s * (_rng.nextBool() ? 1 : -1) * 0.8,
        vy: sin(a) * s * 0.5,
        life: 0.35 + _rng.nextDouble() * 0.25,
        size: h * (0.006 + _rng.nextDouble() * 0.008),
        color: Colors.white.withValues(alpha: 0.55),
      ));
    }
  }

  void _burst(double x, double cy) {
    for (var i = 0; i < 10; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final s = h * (0.12 + _rng.nextDouble() * 0.30);
      particles.add(_Particle(
        x: x,
        y: cy,
        vx: cos(a) * s,
        vy: sin(a) * s,
        life: 0.40 + _rng.nextDouble() * 0.25,
        size: h * (0.005 + _rng.nextDouble() * 0.010),
        color: i.isEven ? _kGold : _kGoldLight,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy -= h * 0.9 * dt;
      p.vx *= 1 - dt * 1.6;
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  // ── Disegno ──────────────────────────────────────────────────────────────

  final Paint _p = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  void paint(Canvas canvas, Size size) {
    if (w == 0 || h == 0) return;

    // Shake su impatto.
    if (_shake > 0.1) {
      canvas.save();
      canvas.translate(
        sin(t * 71) * _shake,
        cos(t * 59) * _shake * 0.6,
      );
    }

    _paintSky(canvas);
    _paintSkyline(canvas);
    _paintGround(canvas);
    _paintCoins(canvas);
    _paintObstacles(canvas);
    _paintPlayer(canvas);
    _paintParticles(canvas);

    if (_shake > 0.1) canvas.restore();

    if (_flash > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFFE53935).withValues(alpha: _flash * 0.35),
      );
    }
  }

  void _paintSky(Canvas canvas) {
    _p.strokeWidth = 0;
    if (_skyGradient == null || _gradientSize != Size(w, h)) {
      _skyGradient = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, h),
        const [Color(0xFF070A14), Color(0xFF171128), Color(0xFF2B1B3D)],
        const [0.0, 0.55, 1.0],
      );
      _gradientSize = Size(w, h);
    }
    _p.shader = _skyGradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
    _p.shader = null;

    // Bagliore dorato all'orizzonte (il lucido del Lelas).
    final glow = ui.Gradient.radial(
      Offset(w * 0.68, groundY),
      w * 0.95,
      [
        _kGold.withValues(alpha: 0.20),
        _kGold.withValues(alpha: 0.06),
        _kGold.withValues(alpha: 0.0),
      ],
      const [0.0, 0.45, 1.0],
    );
    _p.shader = glow;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, groundY + h * 0.1), _p);
    _p.shader = null;

    // Stelle
    for (final s in _stars) {
      final twinkle = sin(t * 1.7 + s.dx * 20).abs();
      _p.color = Colors.white.withValues(alpha: 0.10 + twinkle * 0.35);
      canvas.drawCircle(Offset(s.dx * w, s.dy * groundY), 1.1, _p);
    }

    // Luna.
    _p.color = const Color(0xFFFFF3C4).withValues(alpha: 0.85);
    canvas.drawCircle(Offset(w * 0.82, h * 0.13), h * 0.035, _p);
    _p.color = const Color(0xFFFFF3C4).withValues(alpha: 0.10);
    canvas.drawCircle(Offset(w * 0.82, h * 0.13), h * 0.075, _p);
  }

  void _paintSkyline(Canvas canvas) {
    final k = h / 780.0;
    final tile = 900.0 * k;

    // Layer lontano
    _paintSkylineLayer(
      canvas,
      _far,
      tile,
      _bgFar,
      h * 0.34,
      k,
      const Color(0xFF141026),
    );
    // Layer vicino
    _paintSkylineLayer(
      canvas,
      _mid,
      tile,
      _bgMid,
      h * 0.20,
      k,
      const Color(0xFF1D1631),
    );
  }

  void _paintSkylineLayer(
    Canvas canvas,
    List<_Building> specs,
    double tile,
    double offset,
    double maxH,
    double k,
    Color color,
  ) {
    final shift = offset % tile;
    final copies = (w / tile).ceil() + 2;

    for (var c = -1; c < copies; c++) {
      for (final b in specs) {
        final x = b.x * k - shift + c * tile;
        if (x > w + 60 || x + b.w * k < -60) continue;
        final bh = b.h * maxH;
        final bw = b.w * k;
        final top = groundY - bh;

        _p.color = color;

        if (b.kind == 1) {
          // Cupola del Duomo
          final cx = x + bw / 2;
          _p.color = color;
          canvas.drawRect(
            Rect.fromLTWH(x + bw * 0.16, top + bh * 0.30, bw * 0.68, bh * 0.70),
            _p,
          );
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, top + bh * 0.32), radius: bw * 0.52),
            pi,
            pi,
            true,
            _p,
          );
          // Lanterna
          canvas.drawRect(
            Rect.fromLTWH(cx - bw * 0.055, top - bh * 0.02, bw * 0.11, bh * 0.36),
            _p,
          );
          canvas.drawCircle(
            Offset(cx, top - bh * 0.04),
            bw * 0.07,
            _p,
          );
        } else if (b.kind == 2) {
          // Campanile
          canvas.drawRect(Rect.fromLTWH(x, top, bw, bh), _p);
          canvas.drawRect(
            Rect.fromLTWH(x - bw * 0.2, top + bh * 0.06, bw * 1.4, bh * 0.05),
            _p,
          );
          canvas.drawRect(
            Rect.fromLTWH(x - bw * 0.2, top + bh * 0.30, bw * 1.4, bh * 0.04),
            _p,
          );
        } else {
          canvas.drawRect(Rect.fromLTWH(x, top, bw, bh), _p);
          // Tetto a punta per alcuni palazzi
          if (b.h > 0.55) {
            final path = Path()
              ..moveTo(x - bw * 0.08, top)
              ..lineTo(x + bw * 0.5, top - bh * 0.10)
              ..lineTo(x + bw * 1.08, top)
              ..close();
            canvas.drawPath(path, _p);
          }
        }
      }
    }
  }

  void _paintGround(Canvas canvas) {
    // Terreno
    final grad = ui.Gradient.linear(
      Offset(0, groundY),
      Offset(0, h),
      const [Color(0xFF1B1428), Color(0xFF0C0A12)],
    );
    _p.shader = grad;
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY), _p);
    _p.shader = null;

    // Linea d'oro
    _p.color = _kGold.withValues(alpha: 0.75);
    canvas.drawRect(Rect.fromLTWH(0, groundY - 2, w, 2), _p);
    _p.color = _kGold.withValues(alpha: 0.10);
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h * 0.03), _p);

    // Strisce in movimento per la velocità
    final step = h * 0.085;
    final off = _bgGround % step;
    _stroke
      ..color = _kGold.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    for (var x = -step - off; x < w + step; x += step) {
      canvas.drawLine(
        Offset(x, groundY + 3),
        Offset(x - h * 0.10, h),
        _stroke,
      );
    }

    // Bordo superiore dei sampietrini
    _p.color = Colors.white.withValues(alpha: 0.035);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY + h * 0.03, w, h * 0.02),
      _p,
    );
  }

  void _paintObstacles(Canvas canvas) {
    for (final o in obstacles) {
      final rect = o.rect(this);
      if (rect.right < -20 || rect.left > w + 20) continue;

      if (o.type == _ObstacleType.air) {
        _paintAirObstacle(canvas, rect, o.seed);
      } else {
        _paintCrate(canvas, rect, o.seed);
      }
    }
  }

  void _paintCrate(Canvas canvas, Rect r, int seed) {
    const colors = [
      Color(0xFF8E3B2F), // terracotta fiorentina
      Color(0xFF1F7A63), // verde Giocolare
      Color(0xFF5B3A7E), // viola Montefalchi
    ];
    final base = colors[seed % colors.length];

    // Ombra a terra
    _p.color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r.center.dx, groundY + 2),
        width: r.width * 1.15,
        height: r.height * 0.16,
      ),
      _p,
    );

    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.10));
    _p.color = base;
    canvas.drawRRect(rr, _p);

    // Faccia superiore
    _p.color = Colors.white.withValues(alpha: 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.22),
        Radius.circular(r.width * 0.10),
      ),
      _p,
    );

    // Nastro dorato
    _p.color = _kGold.withValues(alpha: 0.85);
    canvas.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.16, r.top, r.width * 0.12, r.height),
      _p,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top + r.height * 0.40, r.width, r.height * 0.11),
      _p,
    );

    // Bordo
    _stroke
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 1.5;
    canvas.drawRRect(rr, _stroke);
  }

  void _paintAirObstacle(Canvas canvas, Rect r, int seed) {
    // Cartello sospeso di Giocolare con due eliche.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left, r.top + r.height * 0.22, r.width, r.height * 0.78),
      Radius.circular(r.width * 0.10),
    );
    _p.color = const Color(0xFF2B2A4A);
    canvas.drawRRect(body, _p);

    _p.color = const Color(0xFF1F7A63);
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top + r.height * 0.48, r.width, r.height * 0.24),
      _p,
    );
    _p.color = _kGold;
    canvas.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.46, r.top + r.height * 0.22, r.width * 0.08, r.height * 0.78),
      _p,
    );

    _stroke
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;
    canvas.drawRRect(body, _stroke);

    // Eliche
    final rotorY = r.top + r.height * 0.18;
    for (final cx in [r.left + r.width * 0.22, r.left + r.width * 0.78]) {
      _stroke
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(cx - r.width * 0.22, rotorY),
        Offset(cx + r.width * 0.22, rotorY),
        _stroke,
      );
      _p.color = const Color(0xFF151328);
      canvas.drawCircle(Offset(cx, rotorY), r.width * 0.05, _p);
    }
  }

  void _paintCoins(Canvas canvas) {
    for (final c in coinList) {
      final cx = c.x;
      final cy = groundY - c.height;
      final r = h * 0.022;
      final spin =
          cos(t * 5 + c.phase).abs().clamp(0.25, 1.0).toDouble();

      // Alone
      _p.color = _kGold.withValues(alpha: 0.10);
      canvas.drawCircle(Offset(cx, cy), r * 1.35, _p);

      // Moneta (ellisse per l'effetto rotazione)
      _p.color = _kGold;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2 * spin, height: r * 2),
        _p,
      );
      _p.color = _kGoldLight;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: r * 1.15 * spin,
          height: r * 1.15,
        ),
        _p,
      );

      // Simbolo € stilizzato al centro
      _p.color = const Color(0xFF7A5C10).withValues(alpha: 0.75);
      final lw = max(1.0, r * 0.14);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: lw,
          height: r * 0.9,
        ),
        _p,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx - r * 0.10, cy - r * 0.22),
          width: r * 0.44,
          height: lw,
        ),
        _p,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx - r * 0.10, cy + r * 0.18),
          width: r * 0.44,
          height: lw,
        ),
        _p,
      );
    }
  }

  void _paintPlayer(Canvas canvas) {
    final cx = playerX;
    final feet = groundY - y;
    final ph = playerHeight;
    final pw = playerWidth;
    final k = h / 780;

    // Ombra
    final shadowScale = (1 - (y / (h * 0.30))).clamp(0.35, 1.0).toDouble();
    _p.color = Colors.black.withValues(alpha: 0.35 * shadowScale);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 2),
        width: pw * 1.5 * shadowScale,
        height: 7 * k * shadowScale,
      ),
      _p,
    );

    if (sliding) {
      _paintLelasSliding(canvas, cx, feet, ph, pw, k);
    } else {
      _paintLelasRunning(canvas, cx, feet, ph, pw, k);
    }
  }

  void _paintLelasRunning(
    Canvas canvas,
    double cx,
    double feet,
    double ph,
    double pw,
    double k,
  ) {
    final suit = const Color(0xFF1B1B30);
    final skin = const Color(0xFFD7A98A);

    final hipY = feet - ph * 0.30;
    final shoulderY = feet - ph * 0.62;
    final swing = onGround ? sin(runCycle) * ph * 0.22 : ph * 0.10;
    final armSwing = onGround ? sin(runCycle + pi) * ph * 0.18 : -ph * 0.20;

    // Gambe
    _stroke
      ..color = const Color(0xFF101020)
      ..strokeWidth = max(2.2, pw * 0.17)
      ..strokeCap = StrokeCap.round;
    if (onGround) {
      canvas.drawLine(Offset(cx, hipY), Offset(cx + swing, feet), _stroke);
      canvas.drawLine(Offset(cx, hipY), Offset(cx - swing, feet), _stroke);
    } else {
      // Gambe raccolte in salto
      canvas.drawLine(
        Offset(cx, hipY),
        Offset(cx + pw * 0.30, feet - ph * 0.20),
        _stroke,
      );
      canvas.drawLine(
        Offset(cx, hipY),
        Offset(cx - pw * 0.18, feet - ph * 0.10),
        _stroke,
      );
    }

    // Braccia
    _stroke
      ..color = suit
      ..strokeWidth = max(2.0, pw * 0.14);
    canvas.drawLine(
      Offset(cx, shoulderY + ph * 0.05),
      Offset(cx + pw * 0.38, shoulderY + ph * 0.16 + armSwing * 0.5),
      _stroke,
    );
    canvas.drawLine(
      Offset(cx, shoulderY + ph * 0.05),
      Offset(cx - pw * 0.38, shoulderY + ph * 0.16 - armSwing * 0.5),
      _stroke,
    );

    // Busto (giacca)
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, (shoulderY + hipY) / 2 + ph * 0.02),
        width: pw * 0.92,
        height: (hipY - shoulderY) + ph * 0.14,
      ),
      Radius.circular(pw * 0.30),
    );
    _p.color = suit;
    canvas.drawRRect(body, _p);

    // Camicia
    final shirt = Path()
      ..moveTo(cx - pw * 0.16, shoulderY + ph * 0.02)
      ..lineTo(cx + pw * 0.16, shoulderY + ph * 0.02)
      ..lineTo(cx, hipY + ph * 0.02)
      ..close();
    _p.color = Colors.white.withValues(alpha: 0.92);
    canvas.drawPath(shirt, _p);

    // Cravatta d'oro
    final tie = Path()
      ..moveTo(cx - pw * 0.055, shoulderY + ph * 0.03)
      ..lineTo(cx + pw * 0.055, shoulderY + ph * 0.03)
      ..lineTo(cx, hipY + ph * 0.06)
      ..close();
    _p.color = _kGold;
    canvas.drawPath(tie, _p);

    // Collo
    _p.color = skin;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, shoulderY),
        width: pw * 0.20,
        height: ph * 0.09,
      ),
      _p,
    );

    // Testa con la foto del Lelas
    final headR = ph * 0.20;
    final headCY = shoulderY - headR * 0.85;
    _paintHead(canvas, Offset(cx, headCY), headR);
  }

  void _paintLelasSliding(
    Canvas canvas,
    double cx,
    double feet,
    double ph,
    double pw,
    double k,
  ) {
    final suit = const Color(0xFF1B1B30);

    // Corpo orizzontale
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - ph * 0.42, feet - ph * 0.62, ph * 0.86, ph * 0.44),
      Radius.circular(ph * 0.20),
    );
    _p.color = suit;
    canvas.drawRRect(body, _p);

    // Gambe distese in avanti
    _stroke
      ..color = const Color(0xFF101020)
      ..strokeWidth = max(2.2, pw * 0.16)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + ph * 0.20, feet - ph * 0.28),
      Offset(cx + ph * 0.72, feet - ph * 0.10),
      _stroke,
    );
    canvas.drawLine(
      Offset(cx + ph * 0.20, feet - ph * 0.22),
      Offset(cx + ph * 0.66, feet - ph * 0.02),
      _stroke,
    );

    // Scia
    _p.color = _kGold.withValues(alpha: 0.20);
    canvas.drawOval(
      Rect.fromLTWH(cx - ph * 0.95, feet - ph * 0.35, ph * 0.55, ph * 0.10),
      _p,
    );

    // Testa
    final headR = ph * 0.30;
    _paintHead(canvas, Offset(cx - ph * 0.40, feet - ph * 0.42), headR);
  }

  void _paintHead(Canvas canvas, Offset center, double r) {
    final img = avatar;
    if (img != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      canvas.drawImageRect(
        img,
        src,
        Rect.fromCircle(center: center, radius: r),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    } else {
      _p.color = const Color(0xFFD7A98A);
      canvas.drawCircle(center, r, _p);
      _p.color = const Color(0xFF1B1B30);
      canvas.drawCircle(center + Offset(-r * 0.32, -r * 0.18), r * 0.10, _p);
      canvas.drawCircle(center + Offset(r * 0.32, -r * 0.18), r * 0.10, _p);
      _stroke
        ..color = const Color(0xFF1B1B30)
        ..strokeWidth = max(1.2, r * 0.10)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center + Offset(0, r * 0.12), radius: r * 0.42),
        0.35,
        pi - 0.7,
        false,
        _stroke,
      );
    }

    // Anello d'oro
    _stroke
      ..color = _kGold
      ..strokeWidth = max(2.0, r * 0.14);
    canvas.drawCircle(center, r, _stroke);
  }

  void _paintParticles(Canvas canvas) {
    for (final p in particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      _p.color = p.color.withValues(alpha: p.color.a * a);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(p.x, p.y),
          width: p.size,
          height: p.size,
        ),
        _p,
      );
    }
  }

}

// ───────────────────────────────────────────────────────────────────────────
// Painter
// ───────────────────────────────────────────────────────────────────────────

class _SurfPainter extends CustomPainter {
  _SurfPainter(this.world, Listenable repaint) : super(repaint: repaint);

  final _World world;

  @override
  void paint(Canvas canvas, Size size) {
    world.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _SurfPainter oldDelegate) => false;
}
