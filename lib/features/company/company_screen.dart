import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/session.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_theme.dart';
import '../../core/update/app_update.dart';
import '../subscription/subscription_offers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Onglet « Entreprise » : charte, abonnement, profil et déconnexion.
class CompanyScreen extends StatelessWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final profile = session.profile;
    final branding = profile?.branding;
    final sub = profile?.subscription;
    // Pastille du logo aux couleurs de l'entreprise : seul endroit de l'onglet où elles apparaissent
    final onLogo = readableOn(branding?.primary ?? AppColors.accent);

    final (subLabel, subColor) = switch (sub?.state) {
      'active' => ('Actif', AppColors.success),
      'expiring' => ('Expire bientôt', AppColors.warning),
      _ => ('Expiré', AppColors.danger),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Mon entreprise', style: TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        onRefresh: session.refreshProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: branding?.primary, borderRadius: AppRadius.lgAll),
                      alignment: Alignment.center,
                      child: branding?.logoUrl != null
                          ? Image.network(branding!.logoUrl!, fit: BoxFit.cover, width: 56, height: 56,
                              // Balise <img> sur le web : évite le blocage CORS de /storage
                              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                              errorBuilder: (_, __, ___) => Icon(Icons.business, color: onLogo))
                          : Text((branding?.name ?? '?').characters.first,
                              style: TextStyle(color: onLogo, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(branding?.name ?? '', style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w700)),
                          if (branding?.slogan != null) Text(branding!.slogan!, style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final color in [branding?.primary, branding?.secondary, branding?.accent])
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(color: color, borderRadius: AppRadius.smAll, border: Border.all(color: AppColors.border)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (sub != null)
              SectionCard(
                title: 'Abonnement',
                child: Column(
                  children: [
                    InfoRow('État', subLabel, color: subColor, bold: true),
                    if (sub.plan != null) InfoRow('Formule', sub.plan!),
                    if (sub.endsAt != null) InfoRow('Valable jusqu\'au', formatDate(sub.endsAt)),
                    if (sub.daysLeft != null && sub.daysLeft! >= 0) InfoRow('Jours restants', '${sub.daysLeft}'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.autorenew_rounded),
                        label: const Text('Tarifs et renouvellement'),
                        onPressed: () => showOffersSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Informations, couleurs et devis'),
                    subtitle: const Text('Logo, coordonnées, acompte habituel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/company/edit'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.approval_outlined),
                    title: const Text('Tampon de l\'entreprise'),
                    subtitle: const Text('Cachet apposé sur vos devis'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/company/stamp'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Mon profil'),
                    subtitle: Text(profile?.phoneDisplay ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger)),
                    onTap: () async {
                      final ok = await confirmAction(context, title: 'Se déconnecter ?', message: 'Vous devrez saisir à nouveau votre numéro et votre mot de passe.', confirmLabel: 'Se déconnecter');
                      if (ok) {
                        await session.signOut();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppVersionLabel(),
          ],
        ),
      ),
    );
  }
}
