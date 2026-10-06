/// Erreur renvoyée par l'API, avec son code stable (`error_code`).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.code,
    this.status,
    this.errors,
    this.payload,
  });

  final String message;
  final String? code;
  final int? status;
  final Map<String, dynamic>? errors;
  final dynamic payload;

  /// Première erreur de validation d'un champ (ex. `phone`, `items.0.designation`).
  String? fieldError(String field) {
    final value = errors?[field];
    return value is List && value.isNotEmpty ? value.first.toString() : null;
  }

  @override
  String toString() => message;
}
