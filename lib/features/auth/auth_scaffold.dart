import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/profile.dart';
import '../../core/auth/session.dart';
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
    final brand = context.brand;
    final branding = context.select<Session, Branding>((s) => s.branding);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showBack
          ? AppBar(backgroundColor: Colors.white, foregroundColor: brand.secondaryInk, elevation: 0)
          : null,
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
                  // Filet aux 3 couleurs de l'entreprise
                  Row(
                    children: [
                      Expanded(flex: 3, child: Container(height: 4, decoration: BoxDecoration(color: brand.primary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 4),
                      Expanded(flex: 2, child: Container(height: 4, decoration: BoxDecoration(color: brand.secondary, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 4),
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(color: brand.accent, borderRadius: BorderRadius.circular(2)))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: brand.secondaryInk)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  const SizedBox(height: 28),
                  child,
                  // L'écran porte les couleurs de l'entreprise : on rappelle la plateforme
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
    );
  }
}

/// Logo, nom et slogan de l'entreprise (dernière charte connue sur ce téléphone).
class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.branding});

  final Branding branding;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: brand.primary.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
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
              Text(branding.name, style: TextStyle(color: brand.secondaryInk, fontSize: 18, fontWeight: FontWeight.w800)),
              if (branding.slogan != null)
                Text(branding.slogan!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade800))),
        ],
      ),
    );
  }
}
