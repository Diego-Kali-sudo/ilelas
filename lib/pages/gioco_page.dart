import 'package:flutter/material.dart';

import '../state/lelas_state.dart';
import '../widgets/lelas_avatar.dart';

/// BLOCK LELAS 🧱 — minigioco stile Block Blast.
/// Griglia 8x8, trascini i pezzi, le righe/colonne piene esplodono.
/// Sfondo: la faccia del Lelas dietro la griglia.
/// Easter egg: 100 punti → "Maestro dei Blocchi",
/// 3+ linee in una mossa → "Griglia Devastata".
class GiocoPage extends StatefulWidget {
  const GiocoPage({super.key});

  @override
  State<GiocoPage> createState() => _GiocoPageState();
}

class _GiocoPageState extends State<GiocoPage> {
  static const int _n = 8;

  // Palette "Orologio 2.0": calda, oro e bronzo.
  static const _palette = <Color>[
    Color(0xFFD4AF37), // oro
    Color(0xFFE67E22), // arancio
    Color(0xFFC0392B), // rosso
    Color(0xFF95A5A6), // acciaio
    Color(0xFF1ABC9C), // turchese
    Color(0xFF8E44AD), // viola
  ];

  // Pezzi classici del genere.
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

  // Griglia: null = vuota, altrimenti colore del blocco.
  late List<List<Color?>> _grid;
  late List<_Piece?> _tray; // 3 pezzi disponibili
  int _score = 0;
  int _best = 0;
  int _comboStreak = 0;
  int? _selected; // pezzo selezionato (tap)
  List<(int, int)> _ghost = const []; // anteprima posizionamento
  bool _gameOver = false;
  final GlobalKey _gridKey = GlobalKey();

  /// Converte la posizione globale del drag in coordinate locali della griglia.
  Offset _dragToLocal(DragTargetDetails<int> details) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(details.offset) ?? details.offset;
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    setState(() {
      _grid = List.generate(_n, (_) => List.filled(_n, null));
      _tray = List.filled(3, null);
      _score = 0;
      _comboStreak = 0;
      _selected = null;
      _ghost = const [];
      _gameOver = false;
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

  void _refillTray() {
    for (var i = 0; i < 3; i++) {
      if (_tray[i] != null) continue;
      final shape = _shapes[DateTime.now().microsecondsSinceEpoch % _shapes.length];
      final seed = DateTime.now().microsecondsSinceEpoch + i * 7919;
      _tray[i] = _Piece(
        cells: shape,
        color: _palette[seed % _palette.length],
      );
    }
  }

  void _placePiece(int trayIndex, int r0, int c0) {
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

    // Righe e colonne piene → esplodono.
    final fullRows = [
      for (var r = 0; r < _n; r++)
        if (_grid[r].every((cell) => cell != null)) r,
    ];
    final fullCols = [
      for (var c = 0; c < _n; c++)
        if ([for (var r = 0; r < _n; r++) _grid[r][c]].every((cell) => cell != null)) c,
    ];
    for (final r in fullRows) {
      _grid[r] = List.filled(_n, null);
    }
    for (final c in fullCols) {
      for (var r = 0; r < _n; r++) {
        _grid[r][c] = null;
      }
    }

    final lines = fullRows.length + fullCols.length;
    // Bonus combo: più linee consecutive senza sbagliare, più punti.
    _comboStreak = lines == 0 ? 0 : _comboStreak + lines;
    var gained = placedCells * 3 + lines * 10 * (lines == 0 ? 0 : lines) + _comboStreak * 2;
    if (lines >= 2) gained += 20 * lines; // bonus combinazione

    setState(() {
      _score += gained;
      if (_score > _best) _best = _score;
      _selected = null;
      _ghost = const [];
      if (_tray.every((p) => p == null)) _refillTray();
    });

    if (lines > 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final msg = lines >= 3
          ? '💥 GRIGLIA DEVASTATA! +$gained'
          : lines == 2
              ? '✨ Doppia esplosione! +$gained'
              : '⌚ Linea pulita dal Lelas! +$gained';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
      );
    }

    // Achievement del gioco.
    if (_score >= 100) _unlockAchievement('maestro_dei_blocchi');
    if (lines >= 3) _unlockAchievement('griglia_devastata');

    if (_isGameOver()) {
      setState(() => _gameOver = true);
      _showGameOver();
    }
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

  /// Calcola la cella in alto a sinistra dove finirebbe il pezzo
  /// trascinandolo sopra la griglia.
  List<(int, int)> _ghostCells(_Piece piece, Offset local, double cell) {
    final cols = piece.cells[0].length;
    final rows = piece.cells.length;
    final c0 = ((local.dx - cols * cell / 2) / cell).round();
    final r0 = ((local.dy - rows * cell / 2) / cell).round();
    if (!_canPlace(piece.cells, r0, c0)) return const [];
    final out = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (piece.cells[r][c] == 1) out.add((r0 + r, c0 + c));
      }
    }
    return out;
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
                    opacity: 0.16,
                    child: Image(
                      image: AssetImage(LelasAvatar.assetPath),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: null,
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
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        // ── Griglia di gioco (target dei drag) ──
                        DragTarget<int>(
                          builder: (context, candidate, rejected) {
                            return Container(
                              key: _gridKey,
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var r = 0; r < _n; r++)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var c = 0; c < _n; c++)
                                          _cell(r, c, cell),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                          onMove: (details) {
                            if (_selected == null) return;
                            final piece = _tray[_selected!];
                            if (piece == null) return;
                            final ghost = _ghostCells(piece, _dragToLocal(details), cell);
                            if (_ghost != ghost) {
                              setState(() => _ghost = ghost);
                            }
                          },
                          onWillAcceptWithDetails: (details) => _selected != null,
                          onAcceptWithDetails: (details) {
                            final piece = _tray[_selected!];
                            if (piece == null) return;
                            final ghost = _ghostCells(piece, _dragToLocal(details), cell);
                            if (ghost.isNotEmpty) {
                              _placePiece(_selected!, ghost.first.$1, ghost.first.$2);
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tocca un pezzo e trascinalo sulla griglia',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        // ── Vassoio dei 3 pezzi ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < 3; i++)
                              _traySlot(i, mini),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
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
    final isGhost = _ghost.any((g) => g.$1 == r && g.$2 == c);
    Widget inner;
    if (color != null) {
      inner = Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
          color: Colors.white.withValues(alpha: 0.06),
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
    final w = cols * mini;
    final h = rows * mini;
    return GestureDetector(
      onTap: () => setState(() {
        _selected = selected ? null : index;
        _ghost = const [];
      }),
      child: Container(
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
            feedback: Transform.translate(
              offset: Offset(-w / 2, -h / 2),
              child: _pieceCells(piece, mini),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _pieceCells(piece, mini),
            ),
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
                      boxShadow: [
                        BoxShadow(
                          color: piece.color.withValues(alpha: 0.5),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

class _Piece {
  const _Piece({required this.cells, required this.color});
  final List<List<int>> cells;
  final Color color;
}
