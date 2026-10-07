import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Recharge la PWA sur sa dernière version : le service worker de Flutter garde
/// main.dart.js en cache, on le désinscrit et on vide ses caches avant de recharger.
Future<void> reloadLatest() async {
  try {
    final registrations = (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
    for (final registration in registrations) {
      await registration.unregister().toDart;
    }
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final key in keys) {
      await web.window.caches.delete(key.toDart).toDart;
    }
  } catch (_) {
    // Navigateur sans service worker : un simple rechargement suffit
  }
  web.window.location.reload();
}
