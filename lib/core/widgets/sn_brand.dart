import 'package:flutter/material.dart';

/// Identité de la plateforme SN Devis (distincte de la charte de chaque entreprise).
/// Palette officielle, identique au frontend (frontend/src/styles/tokens.scss).
abstract final class SnColors {
  static const green = Color(0xFF00853F);
  static const greenDark = Color(0xFF006B33);
  static const yellow = Color(0xFFFDEF42);
  static const ink = Color(0xFF17202A);
  static const pageBg = Color(0xFFF5F7F6);
}

/// Symbole SN Devis (document vert coché en jaune).
class SnSymbol extends StatelessWidget {
  const SnSymbol({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/brand/sn-devis-symbol.png', width: size, height: size, filterQuality: FilterQuality.medium);
}

/// Logo complet : symbole + « SN Devis ».
class SnLogo extends StatelessWidget {
  const SnLogo({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/sn-devis-logo.png',
        height: height,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'SN Devis',
      );
}

/// Signature discrète sous les écrans aux couleurs d'une entreprise.
class PoweredBySn extends StatelessWidget {
  const PoweredBySn({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Propulsé par', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        const SnLogo(height: 18),
      ],
    );
  }
}

/// Écran de chargement au démarrage (lecture de la session).
class SnSplash extends StatelessWidget {
  const SnSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SnSymbol(size: 88),
            SizedBox(height: 28),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: SnColors.green)),
          ],
        ),
      ),
    );
  }
}
