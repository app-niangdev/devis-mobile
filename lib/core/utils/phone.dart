import 'package:flutter/services.dart';

/// Mobile sénégalais : 9 chiffres, préfixe 70, 71, 75, 76, 77 ou 78.
final RegExp senegalPhonePattern = RegExp(r'^(70|71|75|76|77|78)[0-9]{7}$');

const String phoneRuleMessage = 'Le numéro doit comporter 9 chiffres et commencer par 70, 71, 75, 76, 77 ou 78.';

/// Chiffres seuls, sans l'indicatif +221 / 00221.
String cleanPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  for (final prefix in ['00221', '221']) {
    if (digits.length == 9 + prefix.length && digits.startsWith(prefix)) {
      return digits.substring(prefix.length);
    }
  }
  return digits;
}

String? validatePhone(String? input, {bool required = true}) {
  final phone = cleanPhone(input ?? '');
  if (phone.isEmpty) {
    return required ? 'Le numéro de téléphone est obligatoire.' : null;
  }
  return senegalPhonePattern.hasMatch(phone) ? null : phoneRuleMessage;
}

/// « 77 123 45 67 »
String formatPhone(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 2 || i == 5 || i == 7) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Met en forme la saisie « 77 123 45 67 » (9 chiffres au plus).
class SenegalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      digits = cleanPhone(digits);
      if (digits.length > 9) {
        digits = digits.substring(0, 9);
      }
    }
    final text = formatPhone(digits);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
