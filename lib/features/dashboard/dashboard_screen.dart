import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/data_changes.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../company/company.dart';
import '../subscription/subscription_offers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with ReloadOnDataChange {
  late Future<Dashboard> _future = _load();

  // Retour sur l'application : les chiffres ont pu changer (autre appareil, devis expirés, nouveau mois)
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<Dashboard> _load() => context.read<DashboardRepository>().get();

  @override
  void onDataChanged() => _refresh();

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<Session>().profile;
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: Text(profile?.branding.name ?? 'Accueil', style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/quotes/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau devis'),
      ),
      body: FutureBuilder<Dashboard>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          if (!snapshot.hasData) {
            return const LoadingView();
          }
          final d = snapshot.data!;
          final daysLeft = d.subscription['days_left'] as int?;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Welcome(firstName: profile?.firstName ?? '', acceptedThisMonth: d.month['accepted_count'] as int? ?? 0),
                const SizedBox(height: 16),
                if (d.subscription['state'] == 'expiring')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Votre abonnement expire ${daysLeft == 0 ? "aujourd'hui" : 'dans $daysLeft jour${(daysLeft ?? 0) > 1 ? 's' : ''}'} '
                            '(${formatDate(d.subscription['ends_at'] as String?)}).',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                        TextButton(
                          onPressed: () => showOffersSheet(context),
                          child: const Text('Renouveler'),
                        ),
                      ],
                    ),
                  ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _Kpi(
                      label: 'Acceptés ce mois',
                      value: formatMoney(d.month['accepted_amount'] as int? ?? 0),
                      hint: '${d.month['accepted_count'] ?? 0} devis',
                      color: const Color(0xFF16A34A),
                      onTap: () => context.go('/quotes?status=accepted'),
                    ),
                    _Kpi(
                      label: 'En attente de réponse',
                      value: '${d.count('sent')}',
                      hint:
                          d.count('sent_expired') > 0
                              ? '${formatMoney(d.total('sent'))} · ${d.count('sent_expired')} expiré${d.count('sent_expired') > 1 ? 's' : ''}'
                              : formatMoney(d.total('sent')),
                      color: const Color(0xFF2563EB),
                      onTap: () => context.go('/quotes?status=sent'),
                    ),
                    _Kpi(
                      label: 'Taux d\'acceptation',
                      value: d.acceptanceRate == null ? '—' : '${d.acceptanceRate!.toStringAsFixed(0)} %',
                      hint: d.acceptanceRate == null ? 'Aucune réponse client' : '${d.count('accepted')} acceptés · ${d.count('refused')} refusés',
                      color: brand.primaryInk,
                    ),
                    _Kpi(
                      label: 'Acomptes reçus',
                      value: formatMoney(d.deposits['received'] as int? ?? 0),
                      hint: 'sur ${formatMoney(d.deposits['expected'] as int? ?? 0)} attendus',
                      color: const Color(0xFFD97706),
                      onTap: () => context.go('/quotes?status=accepted'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'En attente de réponse',
                  trailing: TextButton(onPressed: () => context.go('/quotes?status=sent'), child: const Text('Tout voir')),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child:
                      d.awaiting.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('Aucun devis en attente.', style: TextStyle(color: Colors.grey.shade600)),
                          )
                          : Column(
                            children: [
                              for (final q in d.awaiting)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(q['customer_name'] as String? ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${q['quote_number']} · envoyé le ${formatDate(q['sent_at'] as String?)}${q['is_expired'] == true ? ' · expiré' : ''}',
                                    style: q['is_expired'] == true ? const TextStyle(color: Color(0xFFD97706)) : null,
                                  ),
                                  trailing: Text(formatMoney(q['total_amount'] as int? ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  onTap: () => context.push('/quotes/${q['id']}'),
                                ),
                            ],
                          ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Mini(
                        icon: Icons.edit_note_rounded,
                        label: 'Brouillons',
                        value: '${d.count('draft')}',
                        onTap: () => context.go('/quotes?status=draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Mini(icon: Icons.people_alt_outlined, label: 'Clients', value: '${d.customersCount}', onTap: () => context.go('/customers')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Bandeau d'accueil aux couleurs de l'entreprise.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.firstName, required this.acceptedThisMonth});

  final String firstName;
  final int acceptedThisMonth;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final end = Color.lerp(brand.secondary, brand.primary, 0.35)!;
    final onBanner = readableOn(Color.lerp(brand.secondary, end, 0.5)!);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [brand.secondary, end]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour $firstName 👋', style: TextStyle(color: onBanner, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Voici où en sont vos devis.', style: TextStyle(color: onBanner.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: brand.accent, borderRadius: BorderRadius.circular(20)),
            child: Text(
              acceptedThisMonth == 0 ? 'Aucun devis accepté ce mois-ci' : '$acceptedThisMonth devis accepté${acceptedThisMonth > 1 ? 's' : ''} ce mois-ci',
              style: TextStyle(color: brand.onAccent, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.hint, required this.color, this.onTap});

  final String label;
  final String value;
  final String hint;
  final Color color;

  /// Ouvre la liste des devis correspondant au chiffre.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ),
              Text(hint, style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: context.brand.primaryInk),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
