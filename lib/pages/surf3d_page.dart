import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/lelas_state.dart';
import '../widgets/lelas_avatar.dart';

const Color _kGold3D = Color(0xFFD4AF37);
const Color _kGoldLight3D = Color(0xFFFFE28A);

enum _Phase3D { ready, running, dead }

/// "Lelas Surf 3D": runner a 3 corsie in finta prospettiva.
///
/// La strada converge verso l'orizzonte, gli ostacoli ti vengono addosso
/// diventando sempre più grandi. Il Lelas corre di spalle tra i palazzi di
/// Firenze: swipe orizzontale per cambiare corsia, su per saltare, giù per
/// scivolare.
class Surf3DPage extends StatefulWidget {
  const Surf3DPage({super.key});

  @override
  State<Surf3DPage> createState() => _Surf3DPageState();
}

class _Surf3DPageState extends State<Surf3DPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final FocusNode _focus = FocusNode();
  final _World3D _world = _World3D();

  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  final ValueNotifier<int> _score = ValueNotifier<int>(0);
  final ValueNotifier<int> _coins = ValueNotifier<int>(0);

  _Phase3D _phase = _Phase3D.ready;
  Size _size = Size.zero;
  Duration _lastElapsed = Duration.zero;
  int _best = 0;
  bool _newRecord = false;
  ui.Image? _avatar;

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

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('surf3d_lelas_best') ?? 0;
    if (mounted) setState(() => _best = saved);
  }

  Future<void> _saveBest(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('surf3d_lelas_best', value);
  }

  Future<void> _loadAvatar() async {
    try {
      final data = await rootBundle.load(LelasAvatar.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 192,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _avatar = frame.image);
    } catch (_) {
      // Senza foto si gioca lo stesso.
    }
  }

  // ── Loop ─────────────────────────────────────────────────────────────────

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

    _world.update(dt, running: _phase == _Phase3D.running);

    if (_score.value != _world.score) _score.value = _world.score;
    if (_coins.value != _world.coins) _coins.value = _world.coins;
    if (_world.dead && _phase == _Phase3D.running) _die();
    _repaint.value++;
  }

  void _start() {
    if (_phase == _Phase3D.running) return;
    _lastElapsed = Duration.zero;
    _newRecord = false;
    _world.start();
    setState(() => _phase = _Phase3D.running);
    _focus.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _restart() {
    _world.start();
    _score.value = 0;
    _coins.value = 0;
    _lastElapsed = Duration.zero;
    _newRecord = false;
    setState(() => _phase = _Phase3D.running);
    _focus.requestFocus();
  }

  void _die() {
    _phase = _Phase3D.dead;
    HapticFeedback.heavyImpact();
    final score = _world.score;
    if (score > _best) {
      _newRecord = true;
      _best = score;
      _saveBest(score);
    }
    setState(() {});
    if (score >= 400) _unlock('surfista_del_duomo');
    if (score >= 1200) _unlock('ceo_maratoneta');
    if (score >= 3000) _unlock('re_del_surf');
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
    if (_phase == _Phase3D.ready) {
      _start();
      return;
    }
    if (_phase != _Phase3D.running) return;
    if (_world.jump()) HapticFeedback.lightImpact();
  }

  void _slide() {
    if (_phase != _Phase3D.running) return;
    if (_world.slide()) HapticFeedback.lightImpact();
  }

  void _lane(int dir) {
    if (_phase != _Phase3D.running) return;
    if (_world.changeLane(dir)) HapticFeedback.selectionClick();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _lane(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _lane(1);
      return KeyEventResult.handled;
    }
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
        title: const Text('Lelas Surf 3D 🏙️'),
        actions: [
          IconButton(
            tooltip: 'Ricomincia',
            onPressed: _phase == _Phase3D.dead ? _restart : null,
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
              if (_phase != _Phase3D.dead) _jump();
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -120) _lane(-1);
              if (v > 120) _lane(1);
            },
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 120) _slide();
              if (v < -120) _jump();
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Surf3DPainter(_world, _repaint),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(child: _hud(context)),
                  ),
                  if (_phase == _Phase3D.ready)
                    Positioned.fill(child: _readyOverlay(context)),
                  if (_phase == _Phase3D.dead)
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
      children: [
        // Il Lelas in miniatura: la faccia resta protagonista.
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _kGold3D, width: 2),
            color: const Color(0xFF1B1B30),
          ),
          child: ClipOval(
            child: _avatar == null
                ? const Icon(Icons.person, size: 20, color: _kGold3D)
                : RawImage(
                    image: _avatar,
                    fit: BoxFit.cover,
                    width: 34,
                    height: 34,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: _score,
          builder: (context, value, _) => _pill('$value', _kGold3D),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<int>(
          valueListenable: _coins,
          builder: (context, value, _) => _pill('€ $value', _kGoldLight3D),
        ),
        const Spacer(),
        _pill('🏆 $_best', Colors.white70),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _readyOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.38),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'LELAS SURF 3D',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _kGold3D,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tre corsie, una città, zero riunioni rinviate.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              _hint(Icons.swap_horiz, 'Swipe ← → per cambiare corsia'),
              const SizedBox(height: 8),
              _hint(Icons.swipe_up, 'Swipe ↑ o tap per saltare'),
              const SizedBox(height: 8),
              _hint(Icons.swipe_down, 'Swipe ↓ per scivolare'),
              const SizedBox(height: 8),
              _hint(Icons.toll, 'Raccogli i contratti d\'oro'),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('SI PARTE'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold3D,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
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
    return Container(
      color: Colors.black.withValues(alpha: 0.66),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 32,
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stat('PUNTI', '${_world.score}'),
                  const SizedBox(width: 16),
                  _stat('CONTRATTI', '${_world.coins}'),
                  const SizedBox(width: 16),
                  _stat('RECORD', '$_best'),
                ],
              ),
              if (_newRecord) ...[
                const SizedBox(height: 16),
                const Text(
                  '🏆 NUOVO RECORD!',
                  style: TextStyle(
                    color: _kGoldLight3D,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: const Text('RIPROVA'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold3D,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
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

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kGold3D,
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
// Mondo 3D finto
// ───────────────────────────────────────────────────────────────────────────

enum _ObjKind { crate, gate, wall, coin }

class _Obj {
  _Obj({required this.kind, required this.lane, required this.z, this.lift = 0})
    : w = switch (kind) {
        _ObjKind.crate => 0.80,
        _ObjKind.gate => 0.98,
        _ObjKind.wall => 0.90,
        _ObjKind.coin => 0.30,
      },
      h = switch (kind) {
        _ObjKind.crate => 0.55,
        _ObjKind.gate => 0.48,
        _ObjKind.wall => 1.65,
        _ObjKind.coin => 0.30,
      },
      depth = switch (kind) {
        _ObjKind.crate => 0.70,
        _ObjKind.gate => 0.30,
        _ObjKind.wall => 0.55,
        _ObjKind.coin => 0.30,
      },
      yBottom = kind == _ObjKind.gate ? 0.80 : 0.0;

  final _ObjKind kind;
  final double lane;
  double z;
  final double lift;
  final double w, h, depth, yBottom;
  bool taken = false;
}

enum _SceneryKind { palazzo, cipresso, lampione }

class _Scenery {
  _Scenery({
    required this.z,
    required this.side,
    required this.height,
    required this.kind,
    this.tone = 0.0,
  });
  double z;
  final double side; // -1 sinistra, +1 destra
  final double height;
  final _SceneryKind kind;
  final double tone;
}

class _P3 {
  _P3({
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

class _World3D {
  final Random _rng = Random();

  double w = 0, h = 0;
  double horizonY = 0;
  double camH = 0;
  double lanePx = 0;

  static const double _focal = 3.2;
  static const double _playerZ = 0.55;
  static const double _maxZ = 42.0;

  double t = 0;
  double travelled = 0;
  double distance = 0;
  double speed = 0;

  // Giocatore
  double laneX = 0; // in corsie: -1, 0, 1
  int targetLane = 0;
  double y = 0;
  double vy = 0;
  bool onGround = true;
  bool sliding = false;
  double slideTimer = 0;
  double runCycle = 0;

  int score = 0;
  int coins = 0;
  bool dead = false;
  String deathQuote = '';

  final List<_Obj> objects = [];
  final List<_Scenery> scenery = [];
  final List<_P3> particles = [];

  double _nextRow = 0;
  double _nextScenery = 0;
  double _shake = 0;
  double _flash = 0;

  List<_SkyBuilding> _skyline = [];
  List<Offset> _stars = [];

  static const List<String> _quotes = [
    '"Tre corsie, nessuna scusa." — Lelas',
    '"Il Lelas non evita gli ostacoli: li supera in bilancio." — Lelas',
    '"A Firenze anche correre è un atto di stile." — Lelas',
    '"Il CEO che si ferma, perde il treno delle 8:15." — Lelas',
    '"Scivolare è strategia, non caduta." — Lelas',
  ];

  // ── Proiezione ───────────────────────────────────────────────────────────

  double scaleAt(double z) => _focal / (z + _focal);
  double groundYAt(double z) => horizonY + camH * scaleAt(z);
  double screenX(double x, double z) => w / 2 + x * lanePx * scaleAt(z);

  void resize(Size s) {
    final changed = s.width != w || s.height != h;
    w = s.width;
    h = s.height;
    horizonY = h * 0.40;
    camH = h * 0.58;
    lanePx = w * 0.30;
    if (changed || _skyline.isEmpty) _buildSkyline();
  }

  void _buildSkyline() {
    final sr = Random(3);
    _stars = List.generate(
      46,
      (_) => Offset(sr.nextDouble(), sr.nextDouble() * 0.72),
    );

    final r = Random(17);
    _skyline = [];
    var x = 0.0;
    while (x < 1.0) {
      final bw = 0.02 + r.nextDouble() * 0.04;
      _skyline.add(_SkyBuilding(x, bw, 0.15 + r.nextDouble() * 0.55));
      x += bw + 0.005 + r.nextDouble() * 0.01;
    }
  }

  void start() {
    dead = false;
    y = 0;
    vy = 0;
    onGround = true;
    sliding = false;
    slideTimer = 0;
    laneX = 0;
    targetLane = 0;
    distance = 0;
    travelled = 0;
    speed = 8.5;
    score = 0;
    coins = 0;
    objects.clear();
    particles.clear();
    // Prime file di ostacoli già in strada: niente vuoto iniziale.
    for (var i = 0; i < 3; i++) {
      _spawnRow(atZ: 17.0 + i * 9.0);
    }
    _nextRow = speed * 1.5;
    _shake = 0;
    _flash = 0;
  }

  double get difficulty => min(1.0, distance / 220.0);

  // ── Input ────────────────────────────────────────────────────────────────

  bool jump() {
    if (dead) return false;
    if (onGround) {
      vy = 3.6;
      onGround = false;
      _puff(5);
      return true;
    }
    return false;
  }

  bool slide() {
    if (dead) return false;
    if (!onGround) {
      vy = min(vy, -3.4);
      return true;
    }
    sliding = true;
    slideTimer = 0.55;
    _puff(4);
    return true;
  }

  bool changeLane(int dir) {
    if (dead) return false;
    final next = (targetLane + dir).clamp(-1, 1);
    if (next == targetLane) return false;
    targetLane = next;
    return true;
  }

  // ── Update ───────────────────────────────────────────────────────────────

  void update(double dt, {required bool running}) {
    t += dt;

    if (running) {
      speed = 8.5 + 9.5 * difficulty;
      travelled += speed * dt;
      distance += speed * dt;
      runCycle += dt * (6 + speed * 0.55);
      _updatePlayer(dt);
      _updateSpawn(dt);
      _updateObjects(dt);
      score = (distance * 2.4).floor() + coins * 10;
    } else {
      speed = 2.6;
      travelled += speed * dt;
      runCycle += dt * 7;
      _updatePlayer(dt);
    }

    _updateScenery(dt);
    _updateParticles(dt);

    if (_shake > 0) _shake = max(0.0, _shake - dt * 45);
    if (_flash > 0) _flash = max(0.0, _flash - dt * 2.4);
  }

  void _updatePlayer(double dt) {
    // Cambio corsia fluido.
    final dx = targetLane - laneX;
    if (dx.abs() > 0.001) {
      laneX += dx * min(1.0, dt * 13);
    } else {
      laneX = targetLane.toDouble();
    }

    if (sliding) {
      slideTimer -= dt;
      if (slideTimer <= 0) sliding = false;
    }

    if (!onGround) {
      vy -= 8.5 * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
        onGround = true;
        _puff(3);
      }
    }
  }

  void _updateSpawn(double dt) {
    if (dead) return;

    _nextRow -= speed * dt;
    if (_nextRow <= 0) {
      _spawnRow();
      // Intervallo in secondi, non in metri: la velocità cresce, la
      // reazione umana no.
      final gap = (1.45 - 0.55 * difficulty) + _rng.nextDouble() * 0.35;
      _nextRow = speed * gap;
    }
  }

  void _spawnRow({double atZ = _maxZ}) {
    final d = difficulty;
    final lanes = [0, 1, 2]..shuffle(_rng);
    // Mai tutte e tre le corsie: almeno una via di fuga.
    var blocked = 1;
    if (d > 0.28 && _rng.nextDouble() < 0.5) blocked = 2;

    for (var i = 0; i < blocked; i++) {
      final lane = lanes[i] - 1;
      final kind = _pickKind(d);
      objects.add(_Obj(kind: kind, lane: lane.toDouble(), z: atZ));
    }

    if (blocked < 3 && _rng.nextBool()) {
      final freeLane = lanes[blocked] - 1;
      final n = 4 + _rng.nextInt(3);
      final arc = _rng.nextBool();
      for (var i = 0; i < n; i++) {
        final p = n == 1 ? 0.5 : i / (n - 1);
        final lift = arc ? 0.55 + sin(p * pi) * 0.85 : 0.62;
        objects.add(
          _Obj(
            kind: _ObjKind.coin,
            lane: freeLane.toDouble(),
            z: atZ + i * 1.15,
            lift: lift,
          ),
        );
      }
    }
  }

  _ObjKind _pickKind(double d) {
    if (d < 0.12) return _ObjKind.crate;
    final r = _rng.nextDouble();
    if (r < 0.45) return _ObjKind.crate;
    if (r < 0.78) return _ObjKind.gate;
    return _ObjKind.wall;
  }

  void _updateObjects(double dt) {
    final dz = speed * dt;
    for (final o in objects) {
      o.z -= dz;
    }

    final pcx = laneX;
    final pBottom = y;
    final pTop = y + (sliding ? 0.62 : 1.5);
    final pHalfW = 0.31;

    for (final o in objects) {
      if (o.taken) continue;
      final near = o.z - o.depth / 2;
      final far = o.z + o.depth / 2;
      if (near > _playerZ + 0.35 || far < _playerZ - 0.35) continue;

      if (o.kind == _ObjKind.coin) {
        if ((o.lane - pcx).abs() > 0.45) continue;
        final coinY = o.lift + o.h / 2;
        final playerCenterY = y + (sliding ? 0.31 : 0.75);
        if ((coinY - playerCenterY).abs() > 0.72) continue;
        o.taken = true;
        coins++;
        HapticFeedback.selectionClick();
        _burst(o);
        continue;
      }

      if ((o.lane - pcx).abs() > o.w / 2 + pHalfW) continue;
      final oTop = o.yBottom + o.h;
      if (pTop > o.yBottom && pBottom < oTop) {
        _die();
        return;
      }
    }

    objects.removeWhere((o) => o.taken || o.z < -3);
  }

  void _updateScenery(double dt) {
    _nextScenery -= speed * dt;
    if (_nextScenery <= 0) {
      _nextScenery = 3.2 + _rng.nextDouble() * 2.4;
      final side = _rng.nextBool() ? -1.0 : 1.0;
      final kind = _rng.nextDouble() < 0.72
          ? _SceneryKind.palazzo
          : (_rng.nextBool() ? _SceneryKind.cipresso : _SceneryKind.lampione);
      scenery.add(
        _Scenery(
          z: _maxZ,
          side: side,
          height: kind == _SceneryKind.palazzo
              ? 1.8 + _rng.nextDouble() * 3.2
              : 1.2,
          kind: kind,
          tone: _rng.nextDouble(),
        ),
      );
    }
    for (final s in scenery) {
      s.z -= speed * dt;
    }
    scenery.removeWhere((s) => s.z < -2);
  }

  void _die() {
    if (dead) return;
    dead = true;
    _shake = 16;
    _flash = 1;
    deathQuote = _quotes[_rng.nextInt(_quotes.length)];
    _puff(18);
  }

  // ── Particelle ───────────────────────────────────────────────────────────

  void _puff(int n) {
    final s = scaleAt(_playerZ);
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * pi * 2;
      particles.add(
        _P3(
          x: screenX(laneX, _playerZ),
          y: groundYAt(_playerZ),
          vx: cos(a) * 90 * s,
          vy: sin(a) * 60 * s - 40,
          life: 0.30 + _rng.nextDouble() * 0.25,
          size: 3 + _rng.nextDouble() * 4,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      );
    }
  }

  void _burst(_Obj o) {
    final s = scaleAt(o.z);
    final cx = screenX(o.lane, o.z);
    final cy = groundYAt(o.z) - o.lift * lanePx * s;
    for (var i = 0; i < 9; i++) {
      final a = _rng.nextDouble() * pi * 2;
      particles.add(
        _P3(
          x: cx,
          y: cy,
          vx: cos(a) * 140 * s,
          vy: sin(a) * 140 * s,
          life: 0.35 + _rng.nextDouble() * 0.25,
          size: 2.5 + _rng.nextDouble() * 3.5,
          color: i.isEven ? _kGold3D : _kGoldLight3D,
        ),
      );
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 120 * dt;
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  // ── Disegno ──────────────────────────────────────────────────────────────

  final Paint _p = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void paint(Canvas canvas, Size size) {
    if (w == 0 || h == 0) return;

    if (_shake > 0.1) {
      canvas.save();
      canvas.translate(sin(t * 73) * _shake, cos(t * 61) * _shake * 0.55);
    }

    _paintSky(canvas);
    _paintSkyline(canvas);
    _paintGround(canvas);
    _paintScenery(canvas);
    _paintObjects(canvas);
    _paintParticles(canvas);

    if (_shake > 0.1) canvas.restore();

    if (_flash > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: _flash * 0.30),
      );
    }
  }

  void _paintSky(Canvas canvas) {
    final grad = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, horizonY),
      const [Color(0xFF05070F), Color(0xFF171128), Color(0xFF3A2545)],
      const [0.0, 0.6, 1.0],
    );
    _p.shader = grad;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizonY + 2), _p);
    _p.shader = null;

    // Bagliore dorato sull'orizzonte (oro trasparente, non nero).
    final glow = ui.Gradient.radial(
      Offset(w * 0.5, horizonY),
      w * 0.85,
      [
        _kGold3D.withValues(alpha: 0.26),
        _kGold3D.withValues(alpha: 0.08),
        _kGold3D.withValues(alpha: 0.0),
      ],
      const [0.0, 0.5, 1.0],
    );
    _p.shader = glow;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizonY), _p);
    _p.shader = null;

    // Stelle
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final tw = sin(t * 1.9 + i).abs();
      _p.color = Colors.white.withValues(alpha: 0.10 + tw * 0.32);
      canvas.drawCircle(Offset(star.dx * w, star.dy * horizonY), 1.0, _p);
    }

    // Luna bassa
    _p.color = const Color(0xFFFFF3C4).withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.78, horizonY * 0.34), h * 0.030, _p);
    _p.color = const Color(0xFFFFF3C4).withValues(alpha: 0.09);
    canvas.drawCircle(Offset(w * 0.78, horizonY * 0.34), h * 0.070, _p);
  }

  void _paintSkyline(Canvas canvas) {
    final shift = (laneX * 26 + travelled * 0.9) % w;
    _p.color = const Color(0xFF1A1330);
    for (final b in _skyline) {
      final bx = b.x * w * 1.6 - shift;
      final bw = b.w * w * 1.6;
      final bh = b.h * h * 0.16;
      if (bx + bw < -40 || bx > w + 40) continue;
      canvas.drawRect(Rect.fromLTWH(bx, horizonY - bh, bw, bh + 2), _p);
    }
    // Duomo stilizzato al centro-sinistra
    final cx = w * 0.22 - (shift % w) * 0.02;
    final domeR = w * 0.075;
    _p.color = const Color(0xFF221838);
    canvas.drawRect(
      Rect.fromLTWH(
        cx - domeR * 0.35,
        horizonY - h * 0.075,
        domeR * 0.7,
        h * 0.075,
      ),
      _p,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, horizonY - h * 0.075), radius: domeR),
      pi,
      pi,
      true,
      _p,
    );

    // Foschia sull'orizzonte
    final fog = ui.Gradient.linear(
      Offset(0, horizonY - h * 0.10),
      Offset(0, horizonY + h * 0.05),
      [
        const Color(0xFF2B1B3D).withValues(alpha: 0.0),
        const Color(0xFF2B1B3D).withValues(alpha: 0.55),
        const Color(0xFF2B1B3D).withValues(alpha: 0.0),
      ],
      const [0.0, 0.7, 1.0],
    );
    _p.shader = fog;
    canvas.drawRect(Rect.fromLTWH(0, horizonY - h * 0.10, w, h * 0.15), _p);
    _p.shader = null;
  }

  void _paintGround(Canvas canvas) {
    // Prato/terreno oltre la strada
    final ground = ui.Gradient.linear(Offset(0, horizonY), Offset(0, h), const [
      Color(0xFF120E1D),
      Color(0xFF070610),
    ]);
    _p.shader = ground;
    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, h - horizonY), _p);
    _p.shader = null;

    // Marciapiedi
    _quad(canvas, -2.9, 2.9, _maxZ, 0, const Color(0xFF211A2E));
    // Strada
    _quad(canvas, -1.8, 1.8, _maxZ, 0, const Color(0xFF16111F));

    // Bordi dorati
    _groundLine(canvas, -1.8, const Color(0x55D4AF37), 0.05);
    _groundLine(canvas, 1.8, const Color(0x55D4AF37), 0.05);

    // Linee di mezzeria tratteggiate
    const period = 3.0;
    final first = (travelled / period).floor();
    final last = ((travelled + _maxZ) / period).ceil();
    for (var k = first; k <= last; k++) {
      final z0 = k * period - travelled;
      final z1 = z0 + 1.5;
      if (z1 < 0 || z0 > _maxZ) continue;
      for (final lane in [-0.55, 0.55]) {
        _groundLine(
          canvas,
          lane,
          Colors.white.withValues(alpha: 0.14),
          0.045,
          z0: max(0.0, z0),
          z1: min(_maxZ, z1),
        );
      }
    }
  }

  /// Poligono sul piano stradale tra due quote x, da zFar a zNear.
  void _quad(
    Canvas canvas,
    double x0,
    double x1,
    double zFar,
    double zNear,
    Color color,
  ) {
    final path = Path()
      ..moveTo(screenX(x0, zNear), groundYAt(zNear))
      ..lineTo(screenX(x1, zNear), groundYAt(zNear))
      ..lineTo(screenX(x1, zFar), groundYAt(zFar))
      ..lineTo(screenX(x0, zFar), groundYAt(zFar))
      ..close();
    _p.color = color;
    canvas.drawPath(path, _p);
  }

  void _groundLine(
    Canvas canvas,
    double x,
    Color color,
    double halfWidth, {
    double z0 = 0,
    double z1 = _maxZ,
  }) {
    if (z1 <= z0) return;
    final a = Offset(screenX(x, z1), groundYAt(z1));
    final b = Offset(screenX(x, z0), groundYAt(z0));
    _line
      ..color = color
      ..strokeWidth = max(1.0, halfWidth * lanePx * scaleAt(z0));
    canvas.drawLine(a, b, _line);
  }

  void _paintObjects(Canvas canvas) {
    // Dal più lontano al più vicino.
    final list = List<_Obj>.of(objects)..sort((a, b) => b.z.compareTo(a.z));

    var playerDrawn = false;
    for (final o in list) {
      if (!playerDrawn && o.z < _playerZ) {
        _paintPlayer(canvas);
        playerDrawn = true;
      }
      if (o.z > _maxZ + 2 || o.z < -1.5) continue;
      switch (o.kind) {
        case _ObjKind.coin:
          _paintCoin(canvas, o);
        case _ObjKind.gate:
          _paintGate(canvas, o);
        case _ObjKind.crate:
        case _ObjKind.wall:
          _paintBox(
            canvas,
            x: o.lane,
            z: o.z,
            w: o.w,
            h: o.h,
            d: o.depth,
            yBottom: o.yBottom,
            front: o.kind == _ObjKind.wall
                ? const Color(0xFF5B3A7E)
                : const Color(0xFF8E3B2F),
          );
      }
    }
    if (!playerDrawn) _paintPlayer(canvas);
  }

  void _paintBox(
    Canvas canvas, {
    required double x,
    required double z,
    required double w,
    required double h,
    required double d,
    required double yBottom,
    required Color front,
    bool accent = true,
    bool windows = false,
  }) {
    final zN = z - d / 2;
    final zF = z + d / 2;
    if (zF < -0.5) return;

    final sN = scaleAt(zN);
    final sF = scaleAt(zF);
    final gN = groundYAt(zN);
    final gF = groundYAt(zF);
    final nL = screenX(x - w / 2, zN);
    final nR = screenX(x + w / 2, zN);
    final fL = screenX(x - w / 2, zF);
    final fR = screenX(x + w / 2, zF);
    final nT = gN - (yBottom + h) * lanePx * sN;
    final fT = gF - (yBottom + h) * lanePx * sF;
    final nB = gN - yBottom * lanePx * sN;
    final fB = gF - yBottom * lanePx * sF;
    final fog = _fogT(zN);

    // Ombra a terra
    if (fog < 0.92) {
      _p.color = Colors.black.withValues(alpha: 0.34 * (1 - fog));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset((nL + nR) / 2, gN),
          width: (nR - nL) * 1.15,
          height: max(3.0, (nR - nL) * 0.14),
        ),
        _p,
      );
    }

    // Faccia laterale (quella rivolta verso il centro strada)
    final side = x > 0 ? nL : nR;
    final sideF = x > 0 ? fL : fR;
    final sidePath = Path()
      ..moveTo(side, nT)
      ..lineTo(sideF, fT)
      ..lineTo(sideF, fB)
      ..lineTo(side, nB)
      ..close();
    _p.color = _fogged(_darken(front, 0.55), zN);
    canvas.drawPath(sidePath, _p);

    // Faccia superiore
    final topPath = Path()
      ..moveTo(nL, nT)
      ..lineTo(nR, nT)
      ..lineTo(fR, fT)
      ..lineTo(fL, fT)
      ..close();
    _p.color = _fogged(_lighten(front, 0.20), zN);
    canvas.drawPath(topPath, _p);

    // Faccia frontale
    _p.color = _fogged(front, zN);
    canvas.drawRect(Rect.fromLTRB(nL, nT, nR, nB), _p);

    // Finestre accese: è notte, Firenze è viva.
    if (windows && (nR - nL) > 9 && (nB - nT) > 12) {
      final faceW = nR - nL;
      final faceH = nB - nT;
      const cols = 3;
      final rows = max(2, (h / 1.4).floor());
      final cellW = faceW / cols;
      final cellH = faceH / rows;
      final winW = max(1.6, cellW * 0.36);
      final winH = max(2.0, cellH * 0.34);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final lit = ((r * 7 + c * 3) % 5) < 2;
          _p.color = lit
              ? const Color(0xFFFFD98A)
                    .withValues(alpha: 0.34 * (1 - fog * 0.7))
              : const Color(0xFF120E1C).withValues(alpha: 0.25);
          canvas.drawRect(
            Rect.fromLTWH(
              nL + cellW * (c + 0.32),
              nT + cellH * (r + 0.36),
              winW,
              winH,
            ),
            _p,
          );
        }
      }
    }

    // Nastro dorato
    if (accent && w > 0.5 && (nR - nL) > 8) {
      final gold = _fogged(_kGold3D, zN).withValues(alpha: 0.85);
      final frame = Rect.fromLTRB(nL, nT, nR, nB);
      final t = max(1.2, (nR - nL) * 0.05);
      _p.color = gold;
      canvas.drawRect(
        Rect.fromLTRB(frame.left, frame.top, frame.right, frame.top + t),
        _p,
      );
      canvas.drawRect(
        Rect.fromLTRB(frame.left, frame.bottom - t, frame.right, frame.bottom),
        _p,
      );
      canvas.drawRect(
        Rect.fromLTRB(frame.left, frame.top, frame.left + t, frame.bottom),
        _p,
      );
      canvas.drawRect(
        Rect.fromLTRB(frame.right - t, frame.top, frame.right, frame.bottom),
        _p,
      );
      // Fascia centrale: il "sigillo" del contratto.
      final bandY = frame.top + frame.height * 0.54;
      canvas.drawRect(
        Rect.fromLTRB(frame.left, bandY, frame.right, bandY + t * 0.9),
        _p,
      );
    }
  }

  void _paintGate(Canvas canvas, _Obj o) {
    // Asta sospesa: bisogna scivolare.
    _paintBox(
      canvas,
      x: o.lane,
      z: o.z,
      w: o.w,
      h: o.h,
      d: o.depth,
      yBottom: o.yBottom,
      front: const Color(0xFF1F7A63),
    );
    // Montanti laterali
    for (final side in [-1.0, 1.0]) {
      _paintBox(
        canvas,
        x: o.lane + side * (o.w / 2 - 0.05),
        z: o.z,
        w: 0.09,
        h: 0.80,
        d: o.depth,
        yBottom: 0,
        front: const Color(0xFF2F4A5A),
      );
    }
    // Strisce di pericolo
    final zN = o.z - o.depth / 2;
    final sN = scaleAt(zN);
    final gN = groundYAt(zN);
    final left = screenX(o.lane - o.w / 2, zN);
    final right = screenX(o.lane + o.w / 2, zN);
    final top = gN - (o.yBottom + o.h) * lanePx * sN;
    final bottom = gN - o.yBottom * lanePx * sN;
    final barW = right - left;
    _p.color = Colors.black.withValues(alpha: 0.30);
    for (var i = 0; i < 6; i++) {
      final bx = left + barW * (i / 6);
      canvas.drawRect(
        Rect.fromLTWH(
          bx,
          top + (bottom - top) * 0.20,
          barW / 12,
          (bottom - top) * 0.55,
        ),
        _p,
      );
    }
  }

  void _paintCoin(Canvas canvas, _Obj o) {
    if (o.z < -1) return;
    final s = scaleAt(o.z);
    final cx = screenX(o.lane, o.z);
    final cy = groundYAt(o.z) - o.lift * lanePx * s;
    final r = 0.14 * lanePx * s;
    if (r < 0.6) return;
    final spin = cos(t * 6 + o.z).abs().clamp(0.28, 1.0).toDouble();

    // Alone morbido: gradiente, non un disco piatto.
    _p.shader = ui.Gradient.radial(Offset(cx, cy), r * 2.6, [
      _kGold3D.withValues(alpha: 0.30),
      _kGold3D.withValues(alpha: 0.0),
    ]);
    canvas.drawCircle(Offset(cx, cy), r * 2.6, _p);
    _p.shader = null;

    // Bordo scuro per staccare dall'asfalto.
    _p.color = const Color(0xFF3B2A10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: (r + max(0.8, r * 0.14)) * 2 * spin,
        height: (r + max(0.8, r * 0.14)) * 2,
      ),
      _p,
    );

    _p.color = _kGold3D;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 2 * spin,
        height: r * 2,
      ),
      _p,
    );
    _p.color = _kGoldLight3D;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.10 * spin, cy - r * 0.12),
        width: r * 0.90 * spin,
        height: r * 0.90,
      ),
      _p,
    );
  }

  void _paintScenery(Canvas canvas) {
    final list = List<_Scenery>.of(scenery)..sort((a, b) => b.z.compareTo(a.z));
    for (final s in list) {
      if (s.z > _maxZ + 4 || s.z < -1) continue;
      final x = s.side * (2.45 + (s.height - 1.8) * 0.05);
      switch (s.kind) {
        case _SceneryKind.palazzo:
          _paintBox(
            canvas,
            x: x,
            z: s.z,
            w: 1.3,
            h: s.height,
            d: 1.3,
            yBottom: 0,
            front: Color.lerp(
              const Color(0xFF241C38),
              const Color(0xFF3B2A4E),
              s.tone,
            )!,
            accent: false,
            windows: true,
          );
        case _SceneryKind.cipresso:
          _paintCypress(canvas, x, s.z);
        case _SceneryKind.lampione:
          _paintLamp(canvas, x, s.z);
      }
    }
  }

  void _paintCypress(Canvas canvas, double x, double z) {
    final s = scaleAt(z);
    final g = groundYAt(z);
    final cx = screenX(x, z);
    final hh = 1.7 * lanePx * s;
    final ww = 0.34 * lanePx * s;
    _p.color = _fogged(const Color(0xFF16321F), z);
    final path = Path()
      ..moveTo(cx, g - hh)
      ..quadraticBezierTo(cx + ww, g - hh * 0.55, cx + ww * 0.35, g)
      ..lineTo(cx - ww * 0.35, g)
      ..quadraticBezierTo(cx - ww, g - hh * 0.55, cx, g - hh)
      ..close();
    canvas.drawPath(path, _p);
  }

  void _paintLamp(Canvas canvas, double x, double z) {
    final s = scaleAt(z);
    final g = groundYAt(z);
    final cx = screenX(x, z);
    final hh = 1.5 * lanePx * s;
    final fog = _fogT(z);

    // Pozza di luce sull'asfalto.
    _p.color = _kGoldLight3D.withValues(alpha: 0.10 * (1 - fog));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, g),
        width: 0.95 * lanePx * s,
        height: max(2.0, 0.28 * lanePx * s),
      ),
      _p,
    );

    _line
      ..color = _fogged(const Color(0xFF3A3350), z)
      ..strokeWidth = max(1.0, 0.05 * lanePx * s);
    canvas.drawLine(Offset(cx, g), Offset(cx, g - hh), _line);

    final halo = (1 - fog * 0.8);
    _p.color = _kGoldLight3D.withValues(alpha: 0.75 * halo);
    canvas.drawCircle(Offset(cx, g - hh), max(1.0, 0.09 * lanePx * s), _p);
    _p.color = _kGoldLight3D.withValues(alpha: 0.10 * halo);
    canvas.drawCircle(Offset(cx, g - hh), max(2.0, 0.22 * lanePx * s), _p);
  }

  void _paintPlayer(Canvas canvas) {
    final s = scaleAt(_playerZ);
    final cx = screenX(laneX, _playerZ);
    final ground = groundYAt(_playerZ);
    final lift = y * lanePx * s;
    final unit = lanePx * s;
    final feet = ground - lift;

    final suit = const Color(0xFF24243A);
    final suitLight = const Color(0xFF32324E);
    final pants = const Color(0xFF17172A);
    final skin = const Color(0xFFC98F6B);
    final hair = const Color(0xFF241610);

    final bodyW = 0.58 * unit;
    final bodyH = (sliding ? 0.84 : 1.34) * unit;
    final hipY = feet - bodyH * (sliding ? 0.22 : 0.36);
    final shoulderY = feet - bodyH * (sliding ? 0.76 : 0.86);

    // Ombra: si allarga a terra, si stringe in volo.
    final shadow = (1 - (y / 2.0)).clamp(0.35, 1.0).toDouble();
    _p.color = Colors.black.withValues(alpha: 0.46 * shadow);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, ground),
        width: bodyW * 1.45 * shadow,
        height: max(5.0, 0.22 * unit * shadow),
      ),
      _p,
    );

    // ── Gambe ────────────────────────────────────────────────────────────
    // Da dietro conta soprattutto il ritmo verticale dei piedi.
    final stride = onGround ? sin(runCycle) : 1.0;
    final legDx = bodyW * 0.17;
    final leftFootY =
        feet - (onGround ? max(0.0, stride) : 0.90) * bodyH * 0.13;
    final rightFootY =
        feet - (onGround ? max(0.0, -stride) : 0.55) * bodyH * 0.13;
    final legW = max(3.0, bodyW * 0.24);

    _line
      ..color = pants
      ..strokeWidth = legW
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - legDx, hipY),
      Offset(cx - legDx, leftFootY),
      _line,
    );
    canvas.drawLine(
      Offset(cx + legDx, hipY),
      Offset(cx + legDx, rightFootY),
      _line,
    );

    // Scarpe dorate
    for (final foot in [
      Offset(cx - legDx - bodyW * 0.02, leftFootY),
      Offset(cx + legDx + bodyW * 0.02, rightFootY),
    ]) {
      _p.color = _kGold3D;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: foot,
            width: bodyW * 0.30,
            height: bodyW * 0.16,
          ),
          Radius.circular(bodyW * 0.08),
        ),
        _p,
      );
      _p.color = _kGoldLight3D.withValues(alpha: 0.55);
      canvas.drawRect(
        Rect.fromCenter(
          center: foot.translate(0, -bodyW * 0.03),
          width: bodyW * 0.16,
          height: max(1.0, bodyW * 0.04),
        ),
        _p,
      );
    }

    // ── Busto visto di spalle ────────────────────────────────────────────
    final shoulder = bodyW / 2;
    final waist = bodyW * 0.40;
    final torso = Path()
      ..moveTo(cx - shoulder, shoulderY + bodyW * 0.12)
      ..quadraticBezierTo(
        cx - shoulder,
        shoulderY,
        cx - shoulder * 0.55,
        shoulderY - bodyW * 0.03,
      )
      ..lineTo(cx + shoulder * 0.55, shoulderY - bodyW * 0.03)
      ..quadraticBezierTo(
        cx + shoulder,
        shoulderY,
        cx + shoulder,
        shoulderY + bodyW * 0.12,
      )
      ..lineTo(cx + waist, hipY + bodyW * 0.04)
      ..quadraticBezierTo(
        cx,
        hipY + bodyW * 0.16,
        cx - waist,
        hipY + bodyW * 0.04,
      )
      ..close();
    _p.color = suit;
    canvas.drawPath(torso, _p);

    // Cucitura dorata sulla schiena.
    _p.color = _kGold3D.withValues(alpha: 0.35);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, (shoulderY + hipY) / 2 + bodyW * 0.06),
        width: max(1.0, bodyW * 0.035),
        height: (hipY - shoulderY).abs() * 0.62,
      ),
      _p,
    );

    // Spalle illuminate da un alone oro sobrio.
    _p.color = _kGoldLight3D.withValues(alpha: 0.06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, shoulderY + bodyW * 0.06),
        width: bodyW * 0.95,
        height: bodyW * 0.26,
      ),
      _p,
    );

    // ── Braccia ──────────────────────────────────────────────────────────
    final swing = onGround ? sin(runCycle) : 0.55;
    final armW = max(2.5, bodyW * 0.17);
    _line
      ..color = suitLight
      ..strokeWidth = armW
      ..strokeCap = StrokeCap.round;
    final shoulderArmY = shoulderY + bodyW * 0.16;
    final leftHand = Offset(
      cx - bodyW * 0.50,
      hipY + bodyW * 0.02 + swing * bodyH * 0.09,
    );
    final rightHand = Offset(
      cx + bodyW * 0.50,
      hipY + bodyW * 0.02 - swing * bodyH * 0.09,
    );
    canvas.drawLine(Offset(cx - bodyW * 0.44, shoulderArmY), leftHand, _line);
    canvas.drawLine(Offset(cx + bodyW * 0.44, shoulderArmY), rightHand, _line);

    _p.color = skin;
    canvas.drawCircle(leftHand, armW * 0.48, _p);
    canvas.drawCircle(rightHand, armW * 0.48, _p);

    // ── Collo e testa ────────────────────────────────────────────────────
    _p.color = skin;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, shoulderY + bodyW * 0.02),
        width: bodyW * 0.20,
        height: bodyW * 0.18,
      ),
      _p,
    );

    final headR = bodyW * 0.30;
    final headCy = shoulderY - headR * 1.05;

    // Orecchie: dietro la testa, sporgono appena.
    _p.color = skin;
    canvas.drawCircle(
      Offset(cx - headR * 1.00, headCy + headR * 0.18),
      headR * 0.17,
      _p,
    );
    canvas.drawCircle(
      Offset(cx + headR * 1.00, headCy + headR * 0.18),
      headR * 0.17,
      _p,
    );

    // Nuca / capelli
    _p.color = hair;
    canvas.drawCircle(Offset(cx, headCy), headR, _p);

    // Luce dorata sui capelli: solo un filo di controluce.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, headCy), radius: headR * 0.90),
      pi * 1.14,
      pi * 0.40,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, headR * 0.14)
        ..strokeCap = StrokeCap.round
        ..color = _kGold3D.withValues(alpha: 0.30),
    );
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

  static const Color _kFog = Color(0xFF2B1B3D);

  /// Quanto un oggetto a distanza [z] è inghiottito dalla foschia.
  double _fogT(double z) =>
      ((z - 6.0) / (_maxZ - 6.0)).clamp(0.0, 1.0).toDouble();

  Color _fogged(Color c, double z) => Color.lerp(c, _kFog, _fogT(z) * 0.85)!;

  static Color _darken(Color c, double f) =>
      Color.from(alpha: c.a, red: c.r * f, green: c.g * f, blue: c.b * f);

  static Color _lighten(Color c, double f) => Color.from(
    alpha: c.a,
    red: c.r + (1 - c.r) * f,
    green: c.g + (1 - c.g) * f,
    blue: c.b + (1 - c.b) * f,
  );
}

class _SkyBuilding {
  _SkyBuilding(this.x, this.w, this.h);
  final double x;
  final double w;
  final double h;
}

class _Surf3DPainter extends CustomPainter {
  _Surf3DPainter(this.world, Listenable repaint) : super(repaint: repaint);
  final _World3D world;

  @override
  void paint(Canvas canvas, Size size) => world.paint(canvas, size);

  @override
  bool shouldRepaint(covariant _Surf3DPainter oldDelegate) => false;
}
