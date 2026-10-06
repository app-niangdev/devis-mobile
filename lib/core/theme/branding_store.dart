import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/profile.dart';

/// Dernière charte connue, conservée sur le téléphone : le démarrage et l'écran
/// de connexion gardent les couleurs de l'entreprise même déconnecté.
class BrandingStore {
  static const _key = 'branding';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Branding?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == null ? null : Branding.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Branding branding) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(branding.toJson()));
    } catch (_) {
      // Simple confort d'affichage : sans stockage, les couleurs par défaut s'appliquent
    }
  }
}
