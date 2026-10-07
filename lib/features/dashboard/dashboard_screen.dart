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
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with ReloadOnDataChange {
  /// Période des chiffres affichés : le mois en cours par défaut.
  DashboardPeriod _period = DashboardPeriod.currentMonth();
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

  Future<Dashboard> _load() => context.read<DashboardRepository>().get(period: _period);

  void _setPeriod(DashboardPeriod period) {
    if (period == _period) {
      return;
    }
    _period = period;
    _refresh();
  }

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
          // Changement de période : les chiffres précédents restent affichés pendant le chargement
          final reloading = snapshot.connectionState == ConnectionState.waiting;
          final d = snapshot.data!;
          final daysLeft = d.subscription['days_left'] as int?;
          // Tout l'historique : totaux par statut ; sinon devis acceptés pendant la période
          final acceptedCount = _period.isAllTime ? d.count('accepted') : d.month['accepted_count'] as int? ?? 0;
          final acceptedAmount = _period.isAllTime ? d.total('accepted') : d.month['accepted_amount'] as int? ?? 0;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Welcome(firstName: profile?.firstName ?? '', accepted: acceptedCount, periodLabel: _period.label),
                const SizedBox(height: 12),
                _PeriodFilter(period: _period, years: d.years, onChanged: _setPeriod),
                SizedBox(height: 16, child: reloading ? const Center(child: LinearProgressIndicator(minHeight: 2)) : null),
                if (d.subscription['state'] == 'expiring')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: AppColors.warningSoft, borderRadius: AppRadius.mdAll),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Votre abonnement expire ${daysLeft == 0 ? "aujourd'hui" : 'dans $daysLeft jour${(daysLeft ?? 0) > 1 ? 's' : ''}'} '
                            '(${formatDate(d.subscription['ends_at'] as String?)}).',
                            style: const TextStyle(color: AppColors.textPrimary),
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
                      label: 'Devis acceptés',
                      value: formatMoney(acceptedAmount),
                      hint: '$acceptedCount devis ${_period.label}',
                      color: AppColors.success,
                      onTap: () => context.go('/quotes?status=accepted'),
                    ),
                    _Kpi(
                      label: 'En attente de réponse',
                      value: '${d.count('sent')}',
                      hint:
                          d.count('sent_expired') > 0
                              ? '${formatMoney(d.total('sent'))} · ${d.count('sent_expired')} expiré${d.count('sent_expired') > 1 ? 's' : ''}'
                              : formatMoney(d.total('sent')),
                      color: AppColors.info,
                      onTap: () => context.go('/quotes?status=sent'),
                    ),
                    _Kpi(
                      label: 'Taux d\'acceptation',
                      value: d.acceptanceRate == null ? '—' : '${d.acceptanceRate!.toStringAsFixed(0)} %',
                      hint: d.acceptanceRate == null ? 'Aucune réponse client' : '${d.count('accepted')} acceptés · ${d.count('refused')} refusés',
                      color: AppColors.accent,
                    ),
                    _Kpi(
                      label: 'Acomptes reçus',
                      value: formatMoney(d.deposits['received'] as int? ?? 0),
                      hint: 'sur ${formatMoney(d.deposits['expected'] as int? ?? 0)} attendus',
                      color: AppColors.warning,
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
                            child: const Text('Aucun devis en attente.', style: TextStyle(color: AppColors.textSecondary)),
                          )
                          : Column(
                            children: [
                              for (final q in d.awaiting)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(q['customer_name'] as String? ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${q['quote_number']} · envoyé le ${formatDate(q['sent_at'] as String?)}${q['is_expired'] == true ? ' · expiré' : ''}',
                                    style: q['is_expired'] == true ? const TextStyle(color: AppColors.warning) : null,
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

/// Bandeau d'accueil anthracite (comme la barre latérale du web), chiffre clé en jaune.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.firstName, required this.accepted, required this.periodLabel});

  final String firstName;
  final int accepted;

  /// « en octobre 2026 », « le 07/10/2026 »…
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(color: AppColors.darkSurface, borderRadius: AppRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour $firstName 👋', style: const TextStyle(fontFamily: AppFonts.heading, color: AppColors.textInverse, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Voici où en sont vos devis.', style: TextStyle(color: AppColors.textInverse.withValues(alpha: 0.8))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(color: AppColors.highlight, borderRadius: AppRadius.pillAll),
            child: Text(
              accepted == 0 ? 'Aucun devis accepté $periodLabel' : '$accepted devis accepté${accepted > 1 ? 's' : ''} $periodLabel',
              style: const TextStyle(color: AppColors.highlightText, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtre de période : année (parmi celles qui ont des devis), mois, ou date précise.
class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({required this.period, required this.years, required this.onChanged});

  final DashboardPeriod period;
  final List<int> years;
  final ValueChanged<DashboardPeriod> onChanged;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: period.date ?? now,
      firstDate: DateTime(years.isEmpty ? now.year : years.last),
      lastDate: now,
      helpText: 'Choisir une date',
    );
    if (picked != null) {
      onChanged(DashboardPeriod(date: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    // L'année affichée doit figurer dans la liste (ex. aucune donnée cette année)
    final yearChoices = {...years, if (period.year != null) period.year!}.toList()..sort((a, b) => b.compareTo(a));

    final dateButton = IconButton.outlined(
      tooltip: 'Date précise',
      onPressed: () => _pickDate(context),
      style: IconButton.styleFrom(side: const BorderSide(color: AppColors.border), shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll)),
      icon: const Icon(Icons.calendar_month_outlined, color: AppColors.accent),
    );

    if (period.date != null) {
      return Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.event, size: 18, color: AppColors.accentHover),
                label: Text(period.label[0].toUpperCase() + period.label.substring(1)),
                selected: true,
                showCheckmark: false,
                deleteButtonTooltipMessage: 'Revenir au mois en cours',
                onDeleted: () => onChanged(DashboardPeriod.currentMonth()),
                onPressed: () => _pickDate(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          dateButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            value: period.year,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Année', isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Toutes')),
              for (final year in yearChoices) DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: (year) => onChanged(DashboardPeriod(year: year, month: year == null ? null : period.month)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int?>(
            value: period.month,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mois', isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous')),
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(monthNames[m - 1][0].toUpperCase() + monthNames[m - 1].substring(1))),
            ],
            // Un mois n'a de sens qu'avec une année
            onChanged: period.year == null ? null : (month) => onChanged(DashboardPeriod(year: period.year, month: month)),
          ),
        ),
        const SizedBox(width: 8),
        dateButton,
      ],
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
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ),
              Text(hint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent),
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
