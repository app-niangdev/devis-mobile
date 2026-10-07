import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
        const Text('Propulsé par', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: AppColors.cardBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SnSymbol(size: 88),
              SizedBox(height: 28),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
