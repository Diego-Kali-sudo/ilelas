# Block Lelas 🗿

L'app-omaggio a **Emanuele "Illelas" Santini**, con i suoi giochi, le sue aziende
e le sue frasi più celebri.

## Scarica

- **Android (APK)**: [ultima release](https://github.com/Diego-Kali-sudo/ilelas/releases/latest)
- **iPhone / iPad / desktop**: [diego-kali-sudo.github.io/ilelas](https://diego-kali-sudo.github.io/ilelas)
  → su Safari: **Condividi → Aggiungi alla Home** e diventa un'app vera, icona compresa.

## Cosa c'è dentro

- **Home**: il Lelas, il livello di lucido e i titoli (Montefalchi SRL, Giocolare
  Società Coop, Genga APS, La Scatola Galluzzo).
- **Aziende**, **Frasi** e **Segreti**: la lore, le citazioni e gli obiettivi da sbloccare.
- **Giochi** (menu 🏃 in alto a destra nella schermata Gioco):
  - **Block Lelas** — puzzle a blocchi 8×8: trascina i pezzi, riempi righe e colonne,
    fai combo e non fermarti finché c'è spazio.
  - **Lelas Surf 2D** — runner laterale tra i tetti di Firenze: salto, doppio salto,
    scivolata e contratti d'oro.
  - **Lelas Surf 3D** — tre corsie in finta prospettiva: la strada scivola verso
    l'orizzonte, il Duomo sullo sfondo e gli ostacoli che ti arrivano addosso.

## Comandi di Lelas Surf

| Azione | Touch | Tastiera |
| --- | --- | --- |
| Cambia corsia | swipe ← / → | ← → oppure A / D |
| Salta | tap oppure swipe ↑ | spazio, ↑ oppure W |
| Scivola | swipe ↓ | ↓ oppure S |

Nel 3D: **salta i colli dorati**, **scivola sotto le sbarre verdi**, **evita i
muretti**: almeno una corsia resta sempre libera.

## Sviluppo

```bash
flutter pub get
flutter run                 # Android / Chrome
flutter test                # smoke test dei giochi e della Home
flutter build apk --release
flutter build web --release --base-href /ilelas/
```

### CI/CD

- `.github/workflows/release-apk.yml` — a ogni push su `main` compila l'APK e
  pubblica una GitHub Release.
- `.github/workflows/deploy-web.yml` — a ogni push su `main` pubblica la versione
  web su GitHub Pages.

## Note

- I record dei giochi sono salvati in locale (`shared_preferences`).
- Su iPhone l'app web va aggiunta alla Home per girare a schermo intero.
