import 'package:flutter/material.dart';

/// Stato globale dell'app: contatori, achievement e sblocco segreto.
/// Singleton con ChangeNotifier: ogni pagina ci si iscrive per sapere
/// quando mostrare gli easter egg.
class LelasState extends ChangeNotifier {
  LelasState._();
  static final LelasState instance = LelasState._();

  // ── Contatori easter egg ──────────────────────────────────────────
  int headTaps = 0; // tocchi sulla testa (Home)
  int clockTaps = 0; // tocchi sull'orologio (pagina Orologio 2.0)
  int quoteTaps = 0; // frasi generate
  int priceTaps = 0; // tocchi sul prezzo del primo orologio

  // ── Sblocco segreto ───────────────────────────────────────────────
  bool unlockAll = false; // codice "orologio2.0"
  bool lelasMode = false; // codice "lelas": pioggia di emoji

  // ── Achievement sbloccati ─────────────────────────────────────────
  final Set<String> achievements = {};

  static const allAchievements = <String, (String, String)>{
    'primo_tocco': ('👋 Primo Lucido', 'Hai toccato la testa per la prima volta.'),
    'pulizia_deluxe': ('✨ Pulizia Deluxe', '10 tocchi: la testa brilla.'),
    'lucentezza_leggendaria': ('🌟 Lucentezza Leggendaria', '25 tocchi: si vede da Marte.'),
    'testa_volante': ('🛸 Testa Volante', '50 tocchi: è decollata.'),
    'orologiaio_onorario': ('⌚ Orologiaio Onorario', 'Hai aperto Orologio 2.0.'),
    'lelas_time': ('🕐 Lelas Time', '5 tocchi sull\'orologio: è sempre ora di lavoro.'),
    'sconto_lelas': ('💸 Sconto Lelas', '3 tocchi sul prezzo: prezzo trattato.'),
    'frase_segreta': ('🤫 Frase Segreta', '7 frasi: hai sbloccato quella vera.'),
    'dipendente_del_mese': ('🏆 Dipendente del Mese', 'Codice segreto inserito!'),
    'lelas_mode': ('🗿 Lelas Mode', 'Pioggia di Lelas attivata.'),
    'maestro_dei_blocchi': ('🧱 Maestro dei Blocchi', '100 punti nel Block Lelas!'),
    'griglia_devastata': ('💥 Griglia Devastata', '3+ righe/colonne in una mossa!'),
  };

  /// Sblocca un achievement e ritorna true se è nuovo (per il popup).
  bool unlock(String id) {
    if (achievements.contains(id)) return false;
    achievements.add(id);
    notifyListeners();
    return true;
  }

  void incrementHeadTaps() {
    headTaps++;
    notifyListeners();
  }

  void incrementClockTaps() {
    clockTaps++;
    notifyListeners();
  }

  void incrementQuoteTaps() {
    quoteTaps++;
    notifyListeners();
  }

  void incrementPriceTaps() {
    priceTaps++;
    notifyListeners();
  }

  void setUnlockAll() {
    unlockAll = true;
    unlock('dipendente_del_mese');
    notifyListeners();
  }

  void setLelasMode() {
    lelasMode = true;
    unlock('lelas_mode');
    notifyListeners();
  }

  void resetAll() {
    headTaps = 0;
    clockTaps = 0;
    quoteTaps = 0;
    priceTaps = 0;
    unlockAll = false;
    lelasMode = false;
    achievements.clear();
    notifyListeners();
  }
}
