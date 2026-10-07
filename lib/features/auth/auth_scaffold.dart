import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/profile.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sn_brand.dart';

/// Mise en page commune des écrans de connexion.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final branding = context.select<Session, Branding>((s) => s.branding);

    // Fond blanc, parfois sans AppBar : icônes de la barre d'état sombres
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatusBar,
      child: Scaffold(
        backgroundColor: AppColors.cardBg,
        appBar: showBack ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (branding.isPlatform)
                      const Align(alignment: Alignment.centerLeft, child: SnLogo(height: 52))
                    else
                      _CompanyHeader(branding: branding),
                    const SizedBox(height: 14),
                    // Filet aux couleurs SN Devis
                    const Row(
                      children: [
                        Expanded(flex: 3, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadius.pillAll), child: SizedBox(height: 4))),
                        SizedBox(width: 4),
                        Expanded(flex: 2, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: AppRadius.pillAll), child: SizedBox(height: 4))),
                        SizedBox(width: 4),
                        Expanded(child: DecoratedBox(decoration: BoxDecoration(color: AppColors.highlight, borderRadius: AppRadius.pillAll), child: SizedBox(height: 4))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 28),
                    child,
                    // En-tête de l'entreprise : on rappelle la plateforme
                    if (!branding.isPlatform) ...[
                      const SizedBox(height: 36),
                      const PoweredBySn(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, nom et slogan de l'entreprise (dernière charte connue sur ce téléphone).
class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.branding});

  final Branding branding;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: branding.logoUrl != null
              ? Image.network(branding.logoUrl!, fit: BoxFit.cover, width: 64, height: 64,
                  // Balise <img> sur le web : évite le blocage CORS de /storage
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(8), child: SnSymbol()))
              : const Padding(padding: EdgeInsets.all(8), child: SnSymbol()),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branding.name, style: const TextStyle(fontFamily: AppFonts.heading, color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              if (branding.slogan != null)
                Text(branding.slogan!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: AppColors.dangerSoft, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.dangerHover))),
        ],
      ),
    );
  }
}
