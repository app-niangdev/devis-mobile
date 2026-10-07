import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../../core/utils/format.dart';
import '../../core/utils/phone.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Forfait proposé par la plateforme.
class OfferPlan {
  OfferPlan.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String? ?? '',
        durationMonths = (json['duration_months'] as num?)?.toInt() ?? 0,
        price = (json['price'] as num?) ?? 0,
        description = json['description'] as String?;

  final String name;
  final int durationMonths;
  final num price;
  final String? description;

  String get durationLabel => durationMonths % 12 == 0
      ? '${durationMonths ~/ 12} an${durationMonths > 12 ? 's' : ''}'
      : '$durationMonths mois';
}

/// Forfaits actifs et contact de l'administrateur pour payer.
class SubscriptionOffers {
  SubscriptionOffers.fromJson(Map<String, dynamic> json)
      : plans = [
          for (final plan in (json['plans'] as List? ?? const []))
            OfferPlan.fromJson(Map<String, dynamic>.from(plan as Map)),
        ],
        contactName = (json['contact'] as Map?)?['name'] as String?,
        phone = (json['contact'] as Map?)?['phone'] as String?,
        whatsapp = (json['contact'] as Map?)?['whatsapp'] as String?,
        paymentMethods = (json['contact'] as Map?)?['payment_methods'] as String?;

  final List<OfferPlan> plans;
  final String? contactName;
  final String? phone;
  final String? whatsapp;
  final String? paymentMethods;

  /// Route publique : utilisable même quand l'abonnement a expiré.
  static Future<SubscriptionOffers> fetch(ApiClient api) async {
    final body = await api.getPublic('/subscription-offers');
    return SubscriptionOffers.fromJson(Map<String, dynamic>.from(body['payload'] as Map? ?? const {}));
  }
}

/// Feuille « Renouveler mon abonnement » ouverte depuis l'accueil ou l'onglet Entreprise.
Future<void> showOffersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Renouveler mon abonnement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            OffersPanel(api: context.read<Session>().api),
          ],
        ),
      ),
    ),
  );
}

/// Tarifs et boutons pour contacter l'administrateur. Silencieux si les offres ne se chargent pas.
class OffersPanel extends StatefulWidget {
  const OffersPanel({super.key, required this.api});

  final ApiClient api;

  @override
  State<OffersPanel> createState() => _OffersPanelState();
}

class _OffersPanelState extends State<OffersPanel> {
  late final Future<SubscriptionOffers> _future = SubscriptionOffers.fetch(widget.api);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionOffers>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final offers = snapshot.data;
        if (offers == null || offers.plans.isEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nos forfaits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            for (final plan in offers.plans)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            plan.description?.isNotEmpty == true ? plan.description! : plan.durationLabel,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(plan.price),
                      style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              [
                'Pour renouveler, payez le forfait choisi${offers.paymentMethods?.isNotEmpty == true ? ' (${offers.paymentMethods})' : ''}',
                'puis contactez ${offers.contactName?.isNotEmpty == true ? offers.contactName : 'l\'administrateur'}.',
              ].join(' '),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            if (offers.whatsapp?.isNotEmpty == true || offers.phone?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (offers.whatsapp?.isNotEmpty == true)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('WhatsApp'),
                      onPressed: () => _open(Uri.parse('https://wa.me/221${cleanPhone(offers.whatsapp!)}'
                          '?text=${Uri.encodeComponent('Bonjour, je souhaite renouveler mon abonnement Devis.')}')),
                    ),
                  if (offers.phone?.isNotEmpty == true)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.call_outlined),
                      label: Text(formatPhone(cleanPhone(offers.phone!))),
                      onPressed: () => _open(Uri(scheme: 'tel', path: '+221${cleanPhone(offers.phone!)}')),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}
