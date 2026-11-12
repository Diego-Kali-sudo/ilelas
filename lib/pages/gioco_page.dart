import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/lelas_state.dart';
import '../widgets/lelas_avatar.dart';

/// BLOCK LELAS 🧱 — minigioco stile Block Blast.
class GiocoPage extends StatefulWidget {
  const GiocoPage({super.key});

  @override
  State<GiocoPage> createState() => _GiocoPageState();
}

class _GiocoPageState extends State<GiocoPage> with TickerProviderStateMixin {
  static const int _n = 8;

  static const _palette = <Color>[
    Color(0xFFD4AF37),
    Color(0xFFE67E22),
    Color(0xFFC0392B),
    Color(0xFF95A5A6),
    Color(0xFF1ABC9C),
    Color(0xFF8E44AD),
  ];

  static const _shapes = <List<List<int>>>[
    [[1]],
    [[1, 1]],
    [[1], [1]],
    [[1, 1, 1]],
    [[1], [1], [1]],
    [[1, 1], [1, 1]],
    [[1, 0], [1, 1]],
    [[0, 1], [1, 1]],
    [[1, 1, 1], [1, 1, 1]],
    [[1, 1, 1], [0, 1, 0]],
    [[1, 1], [0, 1], [0, 1]],
    [[1, 1], [1, 0], [1, 0]],
  ];

  late List<List<Color?>> _grid;
  late List<_Piece?> _tray;
  int _score = 0;
  int _best = 0;
  int _comboStreak = 0;
  int? _selected;
  bool _gameOver = false;

  final ValueNotifier<List<(int, int)>> _ghostNotifier =
      ValueNotifier(const []);

  late final AnimationController _clearController;
  bool _isClearing = false;
  List<(int, int)> _clearingCells = const [];
  int _pendingGain = 0;
  int _pendingLines = 0;
  List<_Particle> _particles = const [];

  int _popupPoints = 0;
  bool _showPopup = false;

  late final AnimationController _shakeController;

  final GlobalKey _gridKey = GlobalKey();
  RenderBox? _gridBox;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _clearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _clearController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _commitClear();
    });
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _restart();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isGameOver()) {
        setState(() => _gameOver = true);
        _showGameOver();
      }
    });
  }

  @override
  void dispose() {
    _clearController.dispose();
    _shakeController.dispose();
    _ghostNotifier.dispose();
    super.dispose();
  }

  Offset _dragToLocal(DragTargetDetails<int> details) {
    _gridBox ??= _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (_gridBox == null || !_gridBox!.hasSize) {
      _gridBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    }
    if (_gridBox == null) {
      // Fallback: usa l'offset globale (meglio di niente)
      return details.offset;
    }
    try {
      final local = _gridBox!.globalToLocal(details.offset);
      return local - const Offset(2, 2);
    } catch (_) {
      return details.offset;
    }
  }

  void _restart() {
    setState(() {
      _grid = List.generate(_n, (_) => List.filled(_n, null));
      _tray = List.filled(3, null);
      _score = 0;
      _comboStreak = 0;
      _selected = null;
      _ghostNotifier.value = const [];
      _gameOver = false;
      _isClearing = false;
      _clearingCells = const [];
      _particles = const [];
      _showPopup = false;
      _refillTray();
    });
  }

  bool _isGameOver() {
    for (final piece in _tray) {
      if (piece == null) continue;
      if (_anyPlacement(piece)) return false;
    }
    return true;
  }

  bool _anyPlacement(_Piece piece) {
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_canPlace(piece.cells, r, c)) return true;
      }
    }
    return false;
  }

  bool _canPlace(List<List<int>> cells, int r0, int c0) {
    for (var r = 0; r < cells.length; r++) {
      for (var c = 0; c < cells[r].length; c++) {
        if (cells[r][c] == 0) continue;
        final rr = r0 + r;
        final cc = c0 + c;
        if (rr < 0 || rr >= _n || cc < 0 || cc >= _n) return false;
        if (_grid[rr][cc] != null) return false;
      }
    }
    return true;
  }

  // ───────────────────────── RANDOMIZZAZIONE STILE BLOCK BLAST ─────────────────────────

  /// Celle ancora libere nella griglia (0..64).
  int get _freeCells {
    var free = 0;
    for (final row in _grid) {
      for (final cell in row) {
        if (cell == null) free++;
      }
    }
    return free;
  }

  /// Peso di un pezzo: i grandi sono più rari, e lo diventano ancora di più
  /// man mano che la griglia si riempie.
  int _weightFor(List<List<int>> shape, double freeRatio) {
    final n = _cellCount(shape);
    if (n <= 2) return 4;
    if (n <= 4) return 3;
    return freeRatio < 0.35 ? 1 : 2;
  }

  /// Estrae uno shape casuale con probabilità pesata, evitando i doppioni.
  List<List<int>> _pickShape(List<List<List<int>>> avoid, double freeRatio) {
    final pool = <List<List<int>>>[];
    for (final s in _shapes) {
      final w = _weightFor(s, freeRatio);
      for (var k = 0; k < w; k++) {
        pool.add(s);
      }
    }
    for (var attempt = 0; attempt < 25; attempt++) {
      final s = pool[_rng.nextInt(pool.length)];
      if (avoid.any((a) => _sameShape(a, s))) continue;
      return s;
    }
    return pool[_rng.nextInt(pool.length)];
  }

  /// Genera [count] pezzi nuovi, garantendo che almeno uno sia piazzabile
  /// (anti soft-lock immediato).
  List<_Piece> _generateBatch(int count) {
    final freeRatio = _freeCells / (_n * _n);
    final pieces = <_Piece>[];
    for (var i = 0; i < count; i++) {
      final shape = _pickShape(
        [for (final p in pieces) p.cells],
        freeRatio,
      );
      pieces.add(_Piece(
        cells: shape,
        color: _palette[_rng.nextInt(_palette.length)],
      ));
    }

    // Nessuno dei nuovi pezzi entra? Rimpiazza il più grosso con uno
    // che ci sta davvero.
    if (!pieces.any(_anyPlacement)) {
      final playable =
          _shapes.where(_anyShapePlacement).toList(growable: false);
      if (playable.isNotEmpty) {
        var worst = 0;
        for (var i = 1; i < pieces.length; i++) {
          if (_cellCount(pieces[i].cells) > _cellCount(pieces[worst].cells)) {
            worst = i;
          }
        }
        pieces[worst] = _Piece(
          cells: playable[_rng.nextInt(playable.length)],
          color: _palette[_rng.nextInt(_palette.length)],
        );
      }
    }
    return pieces;
  }

  bool _anyShapePlacement(List<List<int>> cells) {
    for (var r = 0; r <= _n - cells.length; r++) {
      for (var c = 0; c <= _n - cells[0].length; c++) {
        if (_canPlace(cells, r, c)) return true;
      }
    }
    return false;
  }

  void _refillTray() {
    final empty = <int>[
      for (var i = 0; i < 3; i++)
        if (_tray[i] == null) i,
    ];
    if (empty.isEmpty) return;
    final batch = _generateBatch(empty.length);
    for (var k = 0; k < empty.length; k++) {
      _tray[empty[k]] = batch[k];
    }
  }

  int _cellCount(List<List<int>> s) =>
      s.fold(0, (sum, row) => sum + row.where((v) => v == 1).length);

  bool _sameShape(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (var r = 0; r < a.length; r++) {
      if (a[r].length != b[r].length) return false;
      for (var c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  // ───────────────────────── PLACEMENT / CLEAR ─────────────────────────

  (int, int)? _bestPlacement(_Piece piece, Offset local, double cell) {
    final cols = piece.cells[0].length;
    final rows = piece.cells.length;
    int? bestR, bestC;
    var bestDist = double.infinity;
    for (var r0 = 0; r0 <= _n - rows; r0++) {
      for (var c0 = 0; c0 <= _n - cols; c0++) {
        if (!_canPlace(piece.cells, r0, c0)) continue;
        final cx = (c0 + cols / 2) * cell;
        final cy = (r0 + rows / 2) * cell;
        final d = (cx - local.dx) * (cx - local.dx) +
            (cy - local.dy) * (cy - local.dy);
        if (d < bestDist) {
          bestDist = d;
          bestR = r0;
          bestC = c0;
        }
      }
    }
    if (bestR == null) return null;
    return (bestR, bestC!);
  }

  List<(int, int)> _ghostForFast(_Piece piece, Offset local, double cell) {
    final cols = piece.cells[0].length;
    final rows = piece.cells.length;
    var c0 = (local.dx / cell).floor() - (cols ~/ 2);
    var r0 = (local.dy / cell).floor() - (rows ~/ 2);
    if (c0 < 0) c0 = 0;
    if (r0 < 0) r0 = 0;
    if (c0 > _n - cols) c0 = _n - cols;
    if (r0 > _n - rows) r0 = _n - rows;
    if (!_canPlace(piece.cells, r0, c0)) return const [];
    final out = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (piece.cells[r][c] == 1) out.add((r0 + r, c0 + c));
      }
    }
    return out;
  }

  void _placePiece(int trayIndex, int r0, int c0) {
    if (_isClearing) return;
    final piece = _tray[trayIndex];
    if (piece == null || !_canPlace(piece.cells, r0, c0)) return;

    var placedCells = 0;
    for (var r = 0; r < piece.cells.length; r++) {
      for (var c = 0; c < piece.cells[r].length; c++) {
        if (piece.cells[r][c] == 1) {
          _grid[r0 + r][c0 + c] = piece.color;
          placedCells++;
        }
      }
    }
    _tray[trayIndex] = null;

    final fullRows = [
      for (var r = 0; r < _n; r++)
        if (_grid[r].every((cell) => cell != null)) r,
    ];
    final fullCols = [
      for (var c = 0; c < _n; c++)
        if ([for (var r = 0; r < _n; r++) _grid[r][c]]
            .every((cell) => cell != null))
          c,
    ];
    final lines = fullRows.length + fullCols.length;

    final clearing = <(int, int)>[];
    for (final r in fullRows) {
      for (var c = 0; c < _n; c++) {
        clearing.add((r, c));
      }
    }
    for (final c in fullCols) {
      for (var r = 0; r < _n; r++) {
        if (!clearing.contains((r, c))) clearing.add((r, c));
      }
    }

    _comboStreak = lines == 0 ? 0 : _comboStreak + lines;
    final gained = placedCells * 3 +
        lines * 10 * (lines == 0 ? 0 : lines) +
        _comboStreak * 2 +
        (lines >= 2 ? 20 * lines : 0);

    if (clearing.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _score += gained;
        if (_score > _best) _best = _score;
        _selected = null;
        _ghostNotifier.value = const [];
        if (_tray.every((p) => p == null)) _refillTray();
      });
      _showGainPopup(gained);
      _saveHighScore();
      if (_score >= 100) _unlockAchievement('maestro_dei_blocchi');
      if (_isGameOver()) {
        setState(() => _gameOver = true);
        _showGameOver();
      }
      return;
    }

    final rng = Random();
    final particles = <_Particle>[];
    for (final (r, c) in clearing) {
      final color = _grid[r][c] ?? const Color(0xFFD4AF37);
      for (var i = 0; i < 2; i++) {
        particles.add(_Particle(
          r: r,
          c: c,
          angle: rng.nextDouble() * 2 * pi,
          color: color,
          emoji: rng.nextBool() ? '✨' : '💥',
        ));
      }
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isClearing = true;
      _clearingCells = clearing;
      _pendingGain = gained;
      _pendingLines = lines;
      _selected = null;
      _ghostNotifier.value = const [];
      _particles = particles;
    });
    _clearController.forward(from: 0);
  }

  void _commitClear() {
    for (final (r, c) in _clearingCells) {
      _grid[r][c] = null;
    }
    final lines = _pendingLines;
    final gained = _pendingGain;
    setState(() {
      _isClearing = false;
      _clearingCells = const [];
      _particles = const [];
      _score += gained;
      if (_score > _best) _best = _score;
      if (_tray.every((p) => p == null)) _refillTray();
    });

    if (lines > 0) {
      HapticFeedback.heavyImpact();
      _showGainPopup(gained);
      _saveHighScore();
      final msg = lines >= 3
          ? '💥 GRIGLIA DEVASTATA! +$gained'
          : lines == 2
              ? '✨ Doppia esplosione! +$gained'
              : '⌚ Linea pulita dal Lelas! +$gained';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg), duration: const Duration(milliseconds: 900)),
      );
    }

    if (_score >= 100) _unlockAchievement('maestro_dei_blocchi');
    if (lines >= 3) _unlockAchievement('griglia_devastata');

    if (_isGameOver()) {
      setState(() => _gameOver = true);
      _showGameOver();
    }
  }

  void _showGainPopup(int points) {
    setState(() {
      _popupPoints = points;
      _showPopup = true;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showPopup = false);
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('block_lelas_best') ?? 0;
    if (mounted) setState(() => _best = saved > _best ? saved : _best);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('block_lelas_best', _best);
  }

  void _unlockAchievement(String id) {
    final state = LelasState.instance;
    if (!state.unlock(id)) return;
    final info = LelasState.allAchievements[id]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade700,
        content: Text('${info.$1}\n${info.$2}'),
      ),
    );
  }

  void _showGameOver() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🗿 Il Lelas ha smesso di brillare'),
        content: Text(
          'Nessun pezzo trova più posto!\n\n'
          'Punteggio: $_score\n'
          'Record di sessione: $_best\n\n'
          '"Anche gli orologi si fermano, a volte." — Lelas',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _restart();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Ricarica il lucido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Lelas 🧱'),
        actions: [
          IconButton(
            tooltip: 'Ricomincia',
            onPressed: _gameOver ? null : _restart,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 480.0);
          final cell = ((width - 40 - 7 * 2) / _n).floorToDouble();
          final mini = (cell * 0.55).floorToDouble();
          return Stack(
            children: [
              // Sfondo: la faccia del Lelas dietro tutto.
              const Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.30,
                    child: Image(
                      image: AssetImage(LelasAvatar.assetPath),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PUNTI: $_score',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFD4AF37),
                                    ),
                              ),
                              Text(
                                'RECORD: $_best',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        // ── Griglia di gioco ──
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, _) {
                            final shakeDx = sin(_shakeController.value * pi * 4) *
                                6 *
                                (1 - _shakeController.value);
                            return Transform.translate(
                              offset: Offset(shakeDx, 0),
                              child: RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: DragTarget<int>(
                                    builder: (context, candidate, rejected) {
                                      return Container(
                                        key: _gridKey,
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.20),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFD4AF37),
                                            width: 2,
                                          ),
                                        ),
                                        padding: EdgeInsets.zero,
                                        child: ValueListenableBuilder<
                                            List<(int, int)>>(
                                          valueListenable: _ghostNotifier,
                                          builder: (context, ghost, _) =>
                                              Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (var r = 0; r < _n; r++)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    for (var c = 0; c < _n; c++)
                                                      _cell(r, c, cell),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    onMove: (details) {
                                      if (_isClearing) return;
                                      if (_selected == null) return;
                                      final piece = _tray[_selected!];
                                      if (piece == null) return;
                                      final ghost = _ghostForFast(
                                          piece, _dragToLocal(details), cell);
                                      if (ghost.toString() ==
                                          _ghostNotifier.value.toString()) {
                                        return;
                                      }
                                      _ghostNotifier.value = ghost;
                                    },
                                    onWillAcceptWithDetails: (details) =>
                                        !_isClearing &&
                                        details.data >= 0 &&
                                        details.data < 3,
                                    onAcceptWithDetails: (details) {
                                      final idx = details.data;
                                      if (idx < 0 || idx >= 3) return;
                                      final piece = _tray[idx];
                                      if (piece == null) return;
                                      var bp = _bestPlacement(
                                          piece, _dragToLocal(details), cell);
                                      if (bp == null) {
                                        for (var r0 = 0;
                                            r0 <= _n - piece.cells.length;
                                            r0++) {
                                          for (var c0 = 0;
                                              c0 <=
                                                  _n -
                                                      piece
                                                          .cells[0].length;
                                              c0++) {
                                            if (_canPlace(
                                                piece.cells, r0, c0)) {
                                              bp = (r0, c0);
                                              break;
                                            }
                                          }
                                          if (bp != null) break;
                                        }
                                      }
                                      if (bp != null) {
                                        _placePiece(idx, bp.$1, bp.$2);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trascina i pezzi sulla griglia per piazzarli',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < 3; i++) _traySlot(i, mini),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Popup punteggio fluttuante ──
              if (_showPopup)
                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOut,
                      builder: (context, t, _) => Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, -t * 60),
                          child: Transform.scale(
                            scale: 1 + t * 0.4,
                            child: Text(
                              '+$_popupPoints',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // ── Particelle di esplosione ──
              if (_isClearing)
                SizedBox(
                  width: width,
                  height: _n * cell + 20,
                  child: AnimatedBuilder(
                    animation: _clearController,
                    builder: (context, _) => Stack(
                      children: _particles.map((p) {
                        final t = _clearController.value;
                        final startX = p.c * cell + cell / 2 + 10;
                        final startY = p.r * cell + cell / 2 + 10;
                        final dx = cos(p.angle) * t * 40;
                        final dy = sin(p.angle) * t * 40;
                        return Positioned(
                          left: startX + dx - 8,
                          top: startY + dy - 8,
                          child: Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: (1 + t * 0.6).clamp(0.0, 2.0),
                              child: Text(
                                p.emoji,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: p.color,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(int r, int c, double size) {
    final color = _grid[r][c];
    final isGhost = _ghostNotifier.value.any((g) => g.$1 == r && g.$2 == c);
    final isClearing = _clearingCells.contains((r, c));
    Widget inner;
    if (isClearing) {
      inner = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          final scale = (1.0 - t * 0.75).clamp(0.0, 1.0);
          final opacity = (1.0 - t).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: t * (pi / 4),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color ?? const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else if (color != null) {
      inner = Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else if (isGhost) {
      inner = Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFD4AF37),
            width: 1.5,
          ),
        ),
      );
    } else {
      inner = Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: inner,
    );
  }

  Widget _traySlot(int index, double mini) {
    final piece = _tray[index];
    final selected = _selected == index && piece != null;
    if (piece == null) {
      return SizedBox(width: mini * 3.4, height: mini * 3.4);
    }
    final cols = piece.cells[0].length;
    final rows = piece.cells.length;
    final w = cols * mini + 4;
    final h = rows * mini + 4;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFFD4AF37) : Colors.transparent,
          width: 2,
        ),
      ),
      child: SizedBox(
        width: w,
        height: h,
        child: Draggable<int>(
          data: index,
          onDragStarted: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selected = index;
              _ghostNotifier.value = const [];
            });
          },
          onDragEnd: (_) {
            setState(() {
              _selected = null;
              _ghostNotifier.value = const [];
            });
          },
          feedback: Transform.translate(
            offset: Offset(-w / 2, -h / 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _pieceCells(piece, mini),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _pieceCells(piece, mini),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _pieceCells(piece, mini),
          ),
        ),
      ),
    );
  }

  Widget _pieceCells(_Piece piece, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in piece.cells)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in row)
                if (v == 1)
                  Container(
                    width: size,
                    height: size,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: piece.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                else
                  SizedBox(width: size, height: size),
            ],
          ),
      ],
    );
  }
}

class _Particle {
  const _Particle({
    required this.r,
    required this.c,
    required this.angle,
    required this.color,
    required this.emoji,
  });
  final int r;
  final int c;
  final double angle;
  final Color color;
  final String emoji;
}

class _Piece {
  const _Piece({required this.cells, required this.color});
  final List<List<int>> cells;
  final Color color;
}
