import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/data_changes.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import 'deposit_sheet.dart';
import 'quote.dart';
import 'quote_widgets.dart';

/// Fiche d'un devis : contenu, totaux, acompte et actions selon le statut.
class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> with ReloadOnDataChange {
  Quote? _quote;
  Object? _error;
  bool _busy = false;

  QuotesRepository get _repo => context.read<QuotesRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onDataChanged() => _load();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final quote = await _repo.find(widget.id);
      if (mounted) {
        setState(() => _quote = quote);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  /// Exécute une action et affiche son message ; le devis renvoyé remplace l'affichage.
  Future<void> _run(Future<(Quote, String)> Function() action) async {
    setState(() => _busy = true);
    try {
      final (quote, message) = await action();
      if (!mounted) {
        return;
      }
      setState(() => _quote = quote);
      if (message.isNotEmpty) {
        showMessage(context, message);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    final quote = _quote!;
    setState(() => _busy = true);
    try {
      final bytes = await _repo.pdf(quote.id);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Devis-${quote.number}.pdf')],
        fileNameOverrides: ['Devis-${quote.number}.pdf'],
        text: 'Devis ${quote.number} : ${formatMoney(quote.total)}',
      ));
      if (mounted && quote.status == 'draft') {
        final sent = await confirmAction(
          context,
          title: 'Devis envoyé au client ?',
          message: 'Marquez le devis comme envoyé si vous l\'avez transmis au client.',
          confirmLabel: 'Marquer envoyé',
        );
        if (sent && mounted) {
          await _run(() => _repo.action(quote.id, 'mark-sent'));
        }
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendWhatsapp() async {
    final quote = _quote!;
    final ok = await confirmAction(
      context,
      title: 'Envoyer sur WhatsApp ?',
      message: 'Le devis (PDF) sera envoyé à ${quote.customerName} au ${quote.customer['phone_display'] ?? ''}.',
      confirmLabel: 'Envoyer',
    );
    if (ok) {
      await _run(() => _repo.action(quote.id, 'whatsapp'));
    }
  }

  Future<void> _decide(String decision) async {
    final accepted = decision == 'accepted';
    final ok = await confirmAction(
      context,
      title: accepted ? 'Le client accepte ?' : 'Le client refuse ?',
      message: 'Cette réponse est définitive : le devis ne pourra plus être modifié (vous pourrez le dupliquer).',
      confirmLabel: accepted ? 'Accepté' : 'Refusé',
      danger: !accepted,
    );
    if (ok) {
      await _run(() => _repo.action(_quote!.id, 'decision', {'decision': decision}));
    }
  }

  Future<void> _deposit() async {
    final data = await showDepositSheet(context, _quote!);
    if (data != null) {
      await _run(() => _repo.recordDeposit(_quote!.id, data));
    }
  }

  Future<void> _duplicate() async {
    setState(() => _busy = true);
    try {
      final (copy, message) = await _repo.action(_quote!.id, 'duplicate');
      if (!mounted) {
        return;
      }
      showMessage(context, message);
      context.pushReplacement('/quotes/${copy.id}');
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer ce devis ?',
      message: 'Le devis ${_quote!.number} sera supprimé.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }
    try {
      final message = await _repo.delete(_quote!.id);
      if (mounted) {
        showMessage(context, message);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
  }

  Future<void> _edit() => context.push<bool>('/quotes/${_quote!.id}/edit', extra: _quote);

  @override
  Widget build(BuildContext context) {
    final quote = _quote;

    return Scaffold(
      appBar: AppBar(
        title: Text(quote?.number ?? 'Devis'),
        actions: [
          if (quote != null)
            PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'duplicate' => _duplicate(),
                'mark-sent' => _run(() => _repo.action(quote.id, 'mark-sent')),
                'cancel-deposit' => _run(() => _repo.cancelDeposit(quote.id)),
                'delete' => _delete(),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'duplicate', child: Text('Dupliquer')),
                if (quote.status == 'draft') const PopupMenuItem(value: 'mark-sent', child: Text('Marquer comme envoyé')),
                if (quote.depositReceived != null) const PopupMenuItem(value: 'cancel-deposit', child: Text('Annuler la saisie de l\'acompte')),
                if (quote.status != 'accepted') const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
        ],
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
      ),
      body: _error != null && quote == null
          ? ErrorView(error: _error!, onRetry: _load)
          : quote == null
              ? const LoadingView()
              : RefreshIndicator(onRefresh: _load, child: _content(quote)),
      bottomNavigationBar: quote == null ? null : _actions(quote),
    );
  }

  Widget _content(Quote quote) {
    final scheme = Theme.of(context).colorScheme;
    final supplies = quote.items.where((i) => !i.isLabor).toList();
    final labor = quote.items.where((i) => i.isLabor).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(quote.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    StatusChip(quote.displayStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(quote.customer['phone_display'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary)),
                if (quote.title != null) ...[
                  const SizedBox(height: 10),
                  Text(quote.title!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 10),
                Text(
                  'Créé le ${formatDate(quote.createdAt)}'
                  '${quote.validUntil != null ? ' · valable jusqu\'au ${formatDate(quote.validUntil)}' : ''}'
                  '${quote.sourceNumber != null ? '\nCopie du devis ${quote.sourceNumber}' : ''}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (supplies.isNotEmpty) _lines('Fournitures', supplies, quote.suppliesAmount),
        if (supplies.isNotEmpty && labor.isNotEmpty) const SizedBox(height: 12),
        if (labor.isNotEmpty) _lines('Main-d\'œuvre', labor, quote.laborAmount),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Montants',
          child: Column(
            children: [
              if (quote.discount > 0) ...[
                InfoRow('Sous-total', formatMoney(quote.grossAmount)),
                InfoRow('Remise', '− ${formatMoney(quote.discount)}'),
                const Divider(),
              ],
              InfoRow('Total', formatMoney(quote.total), bold: true, color: AppColors.textPrimary),
              if (quote.depositAmount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: AppRadius.mdAll),
                  child: InfoRow(
                    'Acompte à la commande${quote.depositType == 'percent' ? ' (${quote.depositValue} %)' : ''}',
                    formatMoney(quote.depositAmount),
                    bold: true,
                  ),
                ),
                InfoRow('Solde à la fin des travaux', formatMoney(quote.balanceAmount)),
              ],
            ],
          ),
        ),
        if (quote.status == 'accepted' && quote.depositAmount > 0) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Acompte',
            child: quote.depositReceived == null
                ? const Text('Pas encore reçu.', style: TextStyle(color: AppColors.textSecondary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DepositBadge(status: quote.depositStatus, amount: quote.depositReceived!['amount'] as int? ?? 0),
                      const SizedBox(height: 6),
                      Text(
                        'Reçu le ${formatDate(quote.depositReceived!['received_at'] as String?)} · '
                        '${paymentMethodLabels[quote.depositReceived!['payment_method']] ?? ''}'
                        '${quote.depositReceived!['reference'] != null ? ' · réf. ${quote.depositReceived!['reference']}' : ''}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
          ),
        ],
        if (quote.notes != null) ...[
          const SizedBox(height: 12),
          SectionCard(title: 'Conditions et remarques', child: Text(quote.notes!)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _lines(String title, List<QuoteLine> lines, int subtotal) {
    return SectionCard(
      title: title,
      trailing: Text(formatMoney(subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.designation, style: const TextStyle(fontWeight: FontWeight.w600)),
                        // Main-d'œuvre saisie au forfait : pas de « 1 × montant »
                        if (!line.isLabor || line.quantity != 1)
                          Text(
                            '${formatQuantity(line.quantity)} ${line.unitName ?? ''} × ${formatMoney(line.unitPrice)}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Text(formatMoney(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Actions principales selon le statut.
  Widget _actions(Quote quote) {
    final buttons = <Widget>[];

    if (quote.isEditable) {
      buttons.add(_iconButton(Icons.edit_outlined, 'Modifier', _edit));
    }
    buttons.add(_iconButton(Icons.ios_share_rounded, 'Partager', _sharePdf));
    if (quote.whatsappAvailable) {
      buttons.add(_iconButton(Icons.chat_rounded, 'WhatsApp', _sendWhatsapp));
    }

    Widget? primary;
    if (quote.status == 'sent') {
      primary = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _busy ? null : () => _decide('refused'),
              child: const Text('Refusé'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _busy ? null : () => _decide('accepted'),
              child: const Text('Accepté'),
            ),
          ),
        ],
      );
    } else if (quote.status == 'accepted' && quote.depositAmount > 0 && quote.depositStatus != 'received') {
      primary = FilledButton.icon(
        onPressed: _busy ? null : _deposit,
        icon: const Icon(Icons.savings_outlined),
        label: Text(quote.depositReceived == null ? 'Enregistrer l\'acompte' : 'Modifier l\'acompte'),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(color: AppColors.cardBg, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: buttons),
            if (primary != null) ...[const SizedBox(height: 8), primary],
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton(
      onPressed: _busy ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 12))],
      ),
    );
  }
}
