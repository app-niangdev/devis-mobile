import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/data_changes.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../quotes/quote_widgets.dart';
import 'customer.dart';
import '../../core/theme/app_colors.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with ReloadOnDataChange {
  late Future<Customer> _future = _load();

  Future<Customer> _load() => context.read<CustomersRepository>().find(widget.id);

  void _reload() => setState(() => _future = _load());

  @override
  void onDataChanged() => _reload();

  Future<void> _open(String path, {Object? extra}) => context.push(path, extra: extra);

  Future<void> _delete(Customer customer) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce client ?',
      message: '${customer.name} ne sera plus proposé ; ses devis restent consultables.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      await context.read<CustomersRepository>().delete(customer.id);
      if (mounted) {
        showMessage(context, 'Client supprimé.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Customer>(
      future: _future,
      builder: (context, snapshot) {
        final customer = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(customer?.name ?? 'Client'),
            actions: [
              if (customer != null) ...[
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _open('/customers/${customer.id}/edit', extra: customer),
                ),
                IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(customer)),
              ],
            ],
          ),
          floatingActionButton: customer == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _open('/quotes/new?customer=${customer.id}'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau devis'),
                ),
          body: snapshot.hasError
              ? ErrorView(error: snapshot.error!, onRetry: _reload)
              : customer == null
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        SectionCard(
                          title: 'Coordonnées',
                          child: Column(
                            children: [
                              InfoRow('Téléphone', customer.phoneDisplay),
                              if (customer.address != null) InfoRow('Adresse', customer.address!),
                              if (customer.email != null) InfoRow('E-mail', customer.email!),
                              if (customer.notes != null) ...[
                                const SizedBox(height: 8),
                                Align(alignment: Alignment.centerLeft, child: Text(customer.notes!, style: TextStyle(color: AppColors.textSecondary))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _Stat(label: 'Devis', value: '${customer.quotesCount}')),
                            const SizedBox(width: 12),
                            Expanded(child: _Stat(label: 'Montant accepté', value: formatMoney(customer.acceptedAmount))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Devis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (customer.quotes.isEmpty)
                          Text('Aucun devis pour ce client.', style: TextStyle(color: AppColors.textSecondary)),
                        for (final q in customer.quotes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                onTap: () => _open('/quotes/${q.id}'),
                                title: Text(q.title ?? q.number, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${q.number} · ${formatDate(q.createdAt)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StatusChip(q.isExpired ? 'expired' : q.status),
                                    const SizedBox(height: 4),
                                    Text(formatMoney(q.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }
}

