import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import 'quote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = quoteStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.pillAll),
      child: Text(
        quoteStatusLabels[status] ?? status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, required this.onTap});

  final QuoteSummary quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(quote.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
                  ),
                  StatusChip(quote.displayStatus),
                ],
              ),
              if (quote.title != null) ...[
                const SizedBox(height: 4),
                Text(quote.title!, style: const TextStyle(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${quote.number} · ${formatDate(quote.createdAt)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text(formatMoney(quote.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              if (quote.depositAmount > 0 && quote.status == 'accepted') ...[
                const SizedBox(height: 6),
                DepositBadge(status: quote.depositStatus, amount: quote.depositAmount),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DepositBadge extends StatelessWidget {
  const DepositBadge({super.key, required this.status, required this.amount});

  final String status;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'received' => ('Acompte reçu', AppColors.success),
      'partial' => ('Acompte partiel', AppColors.warning),
      _ => ('Acompte attendu', AppColors.textSecondary),
    };
    return Row(
      children: [
        Icon(Icons.savings_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label · ${formatMoney(amount)}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
