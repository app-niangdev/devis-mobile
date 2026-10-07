import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/data_changes.dart';
import '../../core/auth/profile.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/common.dart';
import 'company.dart';
import '../../core/theme/app_colors.dart';

/// Tampon de l'entreprise : aperçu, couleur d'encre et apposition sur les devis.
class StampScreen extends StatefulWidget {
  const StampScreen({super.key});

  @override
  State<StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<StampScreen> with ReloadOnDataChange {
  /// Encres proposées : bleu tampon, noir, rouge, vert, violet.
  static const _inks = ['#1E3A8A', '#111827', '#B91C1C', '#047857', '#6D28D9'];

  Stamp? _stamp;
  String? _color;
  bool _enabled = false;
  bool _previewing = false;
  bool _saving = false;
  Object? _error;

  StampRepository get _repo => context.read<StampRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Les informations de l'entreprise ont pu changer : nouvel aperçu, même couleur.
  @override
  void onDataChanged() => _preview(_color);

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final stamp = await _repo.preview();
      if (mounted) {
        setState(() {
          _stamp = stamp;
          _color = stamp.color;
          _enabled = stamp.enabled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _preview(String? color) async {
    setState(() {
      _color = color;
      _previewing = true;
    });
    try {
      final stamp = await _repo.preview(color: color);
      if (mounted && color == _color) {
        setState(() => _stamp = stamp);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _previewing = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final (stamp, message) = await _repo.save(enabled: _enabled, color: _color ?? _inks.first);
      if (mounted) {
        setState(() => _stamp = stamp);
        showMessage(context, message);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tampon de l\'entreprise')),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : _stamp == null
              ? const LoadingView()
              : _content(),
      bottomNavigationBar: _stamp == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Enregistrer'),
              ),
            ),
    );
  }

  Widget _content() {
    final brand = context.select<Session, String?>((s) => s.profile == null ? null : colorToHex(s.profile!.branding.primary));
    final inks = [..._inks, if (brand != null && !_inks.contains(brand)) brand];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.memory(_stamp!.image, gaplessPlayback: true),
                    if (_previewing) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Couleur de l\'encre',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final hex in inks)
                Semantics(
                  label: hex == brand ? 'Couleur de l\'entreprise' : hex,
                  selected: hex == _color,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: hex == _color ? null : () => _preview(hex),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex, Colors.black),
                        shape: BoxShape.circle,
                        border: Border.all(color: hex == _color ? AppColors.textPrimary : AppColors.border, width: hex == _color ? 3 : 1),
                      ),
                      child: hex == _color ? const Icon(Icons.check, color: AppColors.textInverse) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('Apposer sur mes devis'),
            subtitle: const Text('Le tampon figure en bas de chaque devis PDF.'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Généré à partir de vos informations'),
            subtitle: const Text('Nom de l\'entreprise, métier et téléphones. Modifiez-les pour mettre le tampon à jour.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/company/edit'),
          ),
        ),
      ],
    );
  }
}
