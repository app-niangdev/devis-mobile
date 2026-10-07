import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/format.dart';
import 'quote.dart';
import '../../core/theme/app_colors.dart';

/// Saisie de l'acompte reçu : montant, date, moyen de paiement, référence.
Future<Map<String, dynamic>?> showDepositSheet(BuildContext context, Quote quote) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DepositSheet(quote: quote),
  );
}

class _DepositSheet extends StatefulWidget {
  const _DepositSheet({required this.quote});

  final Quote quote;

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: '${widget.quote.depositReceived?['amount'] ?? widget.quote.depositAmount}',
  );
  late final _reference = TextEditingController(text: widget.quote.depositReceived?['reference'] as String? ?? '');
  late DateTime _date = DateTime.tryParse(widget.quote.depositReceived?['received_at'] as String? ?? '') ?? DateTime.now();
  late String _method = widget.quote.depositReceived?['payment_method'] as String? ?? 'wave';

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(context, {
      'amount': int.parse(_amount.text),
      'received_at': isoDate(_date),
      'payment_method': _method,
      'reference': _reference.text.trim().isEmpty ? null : _reference.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Acompte reçu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Acompte demandé : ${formatMoney(widget.quote.depositAmount)}', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Montant reçu', suffixText: 'FCFA'),
              validator: (v) {
                final amount = int.tryParse(v ?? '') ?? 0;
                if (amount <= 0) {
                  return 'Saisissez le montant reçu.';
                }
                return amount > widget.quote.total ? 'Le montant dépasse le total du devis.' : null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Reçu le', suffixIcon: Icon(Icons.calendar_today_outlined)),
                child: Text(formatDate(isoDate(_date))),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in paymentMethodLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _method == entry.key,
                    onSelected: (_) => setState(() => _method = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reference,
              decoration: const InputDecoration(labelText: 'Référence de la transaction (facultatif)'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}
