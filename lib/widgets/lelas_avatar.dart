import 'package:flutter/material.dart';

/// Avatar del Lelas. Cerca l'immagine in `assets/images/lelas.png`
/// (il placeholder cartoon fornito con l'app). Se vuoi usare una foto vera,
/// sostituisci quel file (o aggiorna [LelasAvatar.assetPath]) e riavvia l'app.
class LelasAvatar extends StatelessWidget {
  const LelasAvatar({
    super.key,
    this.size = 160,
    this.onTap,
    this.onLongPress,
  });

  static const String assetPath = 'assets/images/lelas.jpg';

  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.secondaryContainer],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Se il file manca, fallback con emoji gigante: niente crash.
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text('🗿', style: TextStyle(fontSize: size * 0.55)),
            ),
          ),
        ),
      ),
    );
  }
}
