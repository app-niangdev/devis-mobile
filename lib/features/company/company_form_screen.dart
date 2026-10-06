import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' show BlockPicker;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/auth/profile.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import 'company.dart';

/// Informations de l'entreprise : identité, 3 couleurs, logo, mentions et réglages des devis.
class CompanyFormScreen extends StatefulWidget {
  const CompanyFormScreen({super.key});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  static const _textFields = {
    'name': 'Nom de l\'entreprise *',
    'trade': 'Métier (plombier, électricien…)',
    'slogan': 'Slogan',
    'address': 'Adresse',
    'phone_call': 'Téléphone',
    'phone_whatsapp': 'WhatsApp',
    'email': 'E-mail',
    'ninea': 'NINEA',
    'rccm': 'RCCM',
  };

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final key in [..._textFields.keys, 'default_deposit_value', 'quote_validity_days', 'quote_footer']) key: TextEditingController(),
  };
  final Map<String, Color> _colors = {};
  String _depositType = 'none';
  String? _logoUrl;
  XFile? _newLogo;
  bool _removeLogo = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final company = await context.read<CompanyRepository>().get();
      for (final key in _controllers.keys) {
        final value = company.data[key];
        _controllers[key]!.text = value == null ? '' : '$value';
      }
      _colors['primary_color'] = parseHexColor(company.text('primary_color'), Branding.defaults.primary);
      _colors['secondary_color'] = parseHexColor(company.text('secondary_color'), Branding.defaults.secondary);
      _colors['accent_color'] = parseHexColor(company.text('accent_color'), Branding.defaults.accent);
      _depositType = company.text('default_deposit_type').isEmpty ? 'none' : company.text('default_deposit_type');
      _logoUrl = company.data['logo_url'] as String?;
    } catch (e) {
      _error = e;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickColor(String key, String label) async {
    var picked = _colors[key]!;
    final hex = TextEditingController(text: colorToHex(picked));
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlockPicker(
                  pickerColor: picked,
                  onColorChanged: (color) => setDialogState(() {
                    picked = color;
                    hex.text = colorToHex(color);
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hex,
                  decoration: const InputDecoration(labelText: 'Code couleur', hintText: '#1D4ED8'),
                  inputFormatters: [LengthLimitingTextInputFormatter(7)],
                  onChanged: (value) {
                    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                      setDialogState(() => picked = parseHexColor(value, picked));
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, picked), child: const Text('Valider')),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _colors[key] = result);
    }
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file != null) {
      setState(() {
        _newLogo = file;
        _removeLogo = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      String? text(String key) => _controllers[key]!.text.trim().isEmpty ? null : _controllers[key]!.text.trim();
      await context.read<CompanyRepository>().save(
        {
          for (final key in _textFields.keys) key: text(key),
          'primary_color': colorToHex(_colors['primary_color']!),
          'secondary_color': colorToHex(_colors['secondary_color']!),
          'accent_color': colorToHex(_colors['accent_color']!),
          'default_deposit_type': _depositType,
          'default_deposit_value': _depositType == 'none' ? '0' : text('default_deposit_value') ?? '0',
          'quote_validity_days': text('quote_validity_days') ?? '30',
          'quote_footer': text('quote_footer'),
        },
        logo: _newLogo,
        removeLogo: _removeLogo,
      );
      if (!mounted) {
        return;
      }
      // Le thème de l'application suit la nouvelle charte
      await context.read<Session>().refreshProfile();
      if (mounted) {
        showMessage(context, 'Informations de l\'entreprise mises à jour.');
        context.pop();
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
      appBar: AppBar(title: const Text('Mon entreprise')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SectionCard(
                        title: 'Logo',
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
                              child: _newLogo != null
                                  ? FutureBuilder(
                                      future: _newLogo!.readAsBytes(),
                                      builder: (_, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : const SizedBox(),
                                    )
                                  : (_logoUrl != null && !_removeLogo)
                                      ? Image.network(_logoUrl!,
                                      fit: BoxFit.cover,
                                      // Balise <img> sur le web : évite le blocage CORS de /storage
                                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))
                                      : const Icon(Icons.image_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                                    onPressed: _pickLogo,
                                    icon: const Icon(Icons.upload_outlined),
                                    label: const Text('Choisir'),
                                  ),
                                  if (_newLogo != null || (_logoUrl != null && !_removeLogo))
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _newLogo = null;
                                        _removeLogo = true;
                                      }),
                                      child: const Text('Retirer'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Couleurs',
                        child: Column(
                          children: [
                            for (final entry in {
                              'primary_color': 'Couleur principale',
                              'secondary_color': 'Couleur secondaire',
                              'accent_color': 'Couleur d\'accent',
                            }.entries)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () => _pickColor(entry.key, entry.value),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: _colors[entry.key], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
                                ),
                                title: Text(entry.value),
                                subtitle: Text(colorToHex(_colors[entry.key]!)),
                                trailing: const Icon(Icons.edit_outlined),
                              ),
                            const SizedBox(height: 8),
                            _Preview(
                              name: _controllers['name']!.text,
                              primary: _colors['primary_color']!,
                              secondary: _colors['secondary_color']!,
                              accent: _colors['accent_color']!,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(() {
                                  _colors['primary_color'] = Branding.defaults.primary;
                                  _colors['secondary_color'] = Branding.defaults.secondary;
                                  _colors['accent_color'] = Branding.defaults.accent;
                                }),
                                icon: const Icon(Icons.restart_alt, size: 18),
                                label: const Text('Couleurs par défaut'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Informations',
                        child: Column(
                          children: [
                            for (final entry in _textFields.entries) ...[
                              TextFormField(
                                controller: _controllers[entry.key],
                                keyboardType: switch (entry.key) {
                                  'phone_call' || 'phone_whatsapp' => TextInputType.phone,
                                  'email' => TextInputType.emailAddress,
                                  _ => TextInputType.text,
                                },
                                decoration: InputDecoration(labelText: entry.value),
                                validator: entry.key == 'name'
                                    ? (v) => (v == null || v.trim().isEmpty) ? 'Le nom de l\'entreprise est obligatoire.' : null
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Devis',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Acompte proposé sur les nouveaux devis', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'none', label: Text('Aucun')),
                                ButtonSegment(value: 'percent', label: Text('%')),
                                ButtonSegment(value: 'amount', label: Text('Montant')),
                              ],
                              selected: {_depositType},
                              onSelectionChanged: (v) => setState(() => _depositType = v.first),
                            ),
                            if (_depositType != 'none') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _controllers['default_deposit_value'],
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: _depositType == 'percent' ? 'Pourcentage' : 'Montant',
                                  suffixText: _depositType == 'percent' ? '%' : 'FCFA',
                                ),
                                validator: (v) {
                                  final value = int.tryParse(v ?? '') ?? 0;
                                  if (value <= 0) {
                                    return 'Saisissez une valeur.';
                                  }
                                  return _depositType == 'percent' && value > 100 ? '100 % au maximum.' : null;
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _controllers['quote_validity_days'],
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(labelText: 'Validité d\'un devis', suffixText: 'jours'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _controllers['quote_footer'],
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Pied de page des devis', alignLabelWithHint: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const ButtonSpinner()
                            : const Text('Enregistrer'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

/// Aperçu en direct des 3 couleurs : dans l'application et sur l'en-tête d'un devis.
class _Preview extends StatelessWidget {
  const _Preview({required this.name, required this.primary, required this.secondary, required this.accent});

  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.from(Branding(name: name, primary: primary, secondary: secondary, accent: accent));
    final title = name.isEmpty ? 'Votre entreprise' : name;
    final tooLight = [
      if (contrastRatio(primary, Colors.white) < 3) 'principale',
      if (contrastRatio(secondary, Colors.white) < 3) 'secondaire',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Dans l\'application', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: brand.secondary,
                child: Text(title, style: TextStyle(color: brand.onSecondary, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: brand.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('Enregistrer', style: TextStyle(color: brand.onPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Text('Tout voir', style: TextStyle(color: brand.primaryInk, fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: brand.accent, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: brand.onAccent),
                          const SizedBox(width: 4),
                          Text('Devis', style: TextStyle(color: brand.onAccent, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Sur vos devis', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: primary, width: 2))),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: TextStyle(color: secondary, fontWeight: FontWeight.w800))),
                    Text('DEVIS', style: TextStyle(color: primary, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                color: secondary,
                child: Text('DÉSIGNATION · QTÉ · MONTANT', style: TextStyle(color: brand.onSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: accent,
                  child: Text('Acompte à la commande', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: brand.onAccent)),
                ),
              ),
            ],
          ),
        ),
        if (tooLight.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Couleur ${tooLight.join(' et ')} très claire : sur fond blanc, l\'application en affichera une version '
                  'plus foncée pour que les textes restent lisibles.',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
