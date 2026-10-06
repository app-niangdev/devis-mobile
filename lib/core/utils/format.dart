/// Montant en FCFA entiers : « 165 550 FCFA ».
String formatMoney(num? value, {bool withCurrency = true}) {
  final amount = (value ?? 0).round();
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '−' : ''}$buffer${withCurrency ? ' FCFA' : ''}';
}

/// Quantité sans zéros inutiles : 12,5 / 4.
String formatQuantity(num value) {
  final text = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
}

/// « 2026-10-03 » ou ISO 8601 → « 03/10/2026 ».
String formatDate(String? iso) {
  if (iso == null || iso.length < 10) {
    return '—';
  }
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) {
    return '—';
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Nombre saisi au clavier (« 12,5 », « 7 500 ») ; null s'il est invalide.
double? parseNumber(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}
