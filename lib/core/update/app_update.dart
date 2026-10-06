import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';

/// Versions publiées par le serveur (`GET /app-version`).
class AppRelease {
  AppRelease.fromJson(Map<String, dynamic> json)
      : latest = (json['latest_version'] ?? '').toString(),
        min = (json['min_version'] ?? '').toString(),
        url = (json['android_url'] ?? '').toString(),
        notes = json['release_notes'] as String?;

  final String latest;
  final String min;
  final String url;
  final String? notes;
}

/// Compare deux versions « 1.2.3 » (le numéro de build après « + » est ignoré).
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) {
      return d.sign;
    }
  }
  return 0;
}

/// L'APK Android ne se met pas à jour tout seul (pas de Play Store) : au démarrage et au retour
/// dans l'app, on compare la version installée à celle du serveur.
/// Plus récente disponible → proposition ; sous la version minimale → écran bloquant.
/// La PWA, elle, se met à jour d'elle-même : aucune vérification sur le web.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.api, required this.navigatorKey, required this.child});

  final ApiClient api;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  static const _interval = Duration(hours: 1);

  late final AppLifecycleListener _lifecycle;
  DateTime? _checkedAt;
  AppRelease? _forced;
  String? _proposed;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final now = DateTime.now();
    // Écran bloquant affiché : on revérifie à chaque retour (l'utilisateur vient peut-être d'installer)
    if (!_supported || (_forced == null && _checkedAt != null && now.difference(_checkedAt!) < _interval)) {
      return;
    }
    _checkedAt = now;

    final AppRelease release;
    final String current;
    try {
      release = AppRelease.fromJson(Map<String, dynamic>.from((await widget.api.get('/app-version'))['payload'] as Map));
      current = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return; // Hors ligne ou serveur indisponible : l'app reste utilisable
    }
    if (!mounted) {
      return;
    }

    final forced = compareVersions(current, release.min) < 0;
    setState(() => _forced = forced ? release : null);

    if (!forced && compareVersions(current, release.latest) < 0 && _proposed != release.latest) {
      _proposed = release.latest;
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        showDialog<void>(context: context, builder: (_) => _UpdateDialog(release: release));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = _forced;
    return forced == null ? widget.child : _ForcedUpdateScreen(release: forced);
  }
}

Future<void> _download(BuildContext context, AppRelease release) async {
  final ok = release.url.isNotEmpty && await launchUrl(Uri.parse(release.url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Impossible d\'ouvrir le lien de téléchargement.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

const _installHint = 'Ouvrez ensuite le fichier téléchargé pour installer la mise à jour. Vos données sont conservées.';

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final notes = release.notes?.trim() ?? '';
    return AlertDialog(
      title: const Text('Mise à jour disponible'),
      content: Text([
        'La version ${release.latest} de l\'application est disponible.',
        if (notes.isNotEmpty) notes,
        _installHint,
      ].join('\n\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () async {
            await _download(context, release);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Mettre à jour'),
        ),
      ],
    );
  }
}

class _ForcedUpdateScreen extends StatelessWidget {
  const _ForcedUpdateScreen({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final notes = release.notes?.trim() ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Mise à jour nécessaire', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Cette version de l\'application n\'est plus prise en charge. '
                  'Installez la version ${release.latest} pour continuer.',
                  textAlign: TextAlign.center,
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(notes, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 12),
                Text(_installHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => _download(context, release),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Télécharger la mise à jour'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Version installée, affichée discrètement (utile quand un utilisateur signale un problème).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) => Text(
        snapshot.hasData ? 'Version ${snapshot.data!.version}' : '',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }
}
