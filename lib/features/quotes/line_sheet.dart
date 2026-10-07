import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import 'quote.dart';
import '../../core/theme/app_colors.dart';

class LineResult {
  LineResult.saved(this.line) : deleted = false;
  LineResult.deleted() : line = null, deleted = true;

  final QuoteLine? line;
  final bool deleted;
}

/// Saisie d'une ligne. Fourniture : désignation (suggestions du catalogue), unité, quantité
/// et prix unitaire. Main-d'œuvre : uniquement le montant.
Future<LineResult?> showLineSheet(BuildContext context, QuoteLine line, {required bool isNew}) {
  return showModalBottomSheet<LineResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LineSheet(line: line, isNew: isNew),
  );
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.line, required this.isNew});

  final QuoteLine line;
  final bool isNew;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  final _formKey = GlobalKey<FormState>();
  late final QuoteLine _line = widget.line;
  late final _designation = TextEditingController(text: _line.designation);
  late final _unit = TextEditingController(text: _line.unitName ?? '');
  late final _quantity = TextEditingController(text: formatQuantity(_line.quantity));
  // Main-d'œuvre : le champ prix porte le montant total de la ligne
  late final _price = TextEditingController(
    text: (_line.isLabor ? _line.subtotal : _line.unitPrice) > 0 ? '${_line.isLabor ? _line.subtotal : _line.unitPrice}' : '',
  );
  final _priceFocus = FocusNode();

  List<CatalogProduct> _suggestions = [];
  Timer? _debounce;
  late List<String> _units = context.read<QuotesRepository>().lastUnits;

  @override
  void initState() {
    super.initState();
    _quantity.addListener(() => setState(() {}));
    _price.addListener(() => setState(() {}));
    _loadUnits();
  }

  /// Met à jour les unités suggérées selon les habitudes de l'entreprise.
  Future<void> _loadUnits() async {
    try {
      final units = await context.read<QuotesRepository>().units();
      if (mounted) {
        setState(() => _units = units);
      }
    } catch (_) {
      // Les suggestions sont facultatives : on garde les dernières connues
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_designation, _unit, _quantity, _price]) {
      c.dispose();
    }
    _priceFocus.dispose();
    super.dispose();
  }

  void _searchProducts(String text) {
    _line.productId = null;
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final products = await context.read<QuotesRepository>().products(text.trim());
        if (mounted) {
          setState(() => _suggestions = products.take(5).toList());
        }
      } catch (_) {
        // Les suggestions sont facultatives
      }
    });
  }

  void _useProduct(CatalogProduct product) {
    setState(() {
      _line.productId = product.id;
      _designation.text = product.name;
      if (product.unitPrice > 0) {
        _price.text = '${product.unitPrice}';
      }
      _suggestions = [];
    });
  }

  int get _subtotal => ((parseNumber(_quantity.text) ?? 0) * (int.tryParse(_price.text) ?? 0)).round();

  void _setKind(String kind) {
    setState(() {
      _line.kind = kind;
      _suggestions = [];
    });
    if (_line.isLabor) {
      _priceFocus.requestFocus();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_line.isLabor) {
      _line
        ..productId = null
        ..designation = laborDesignation
        ..unitName = null
        ..quantity = 1
        ..unitPrice = int.parse(_price.text);
      Navigator.pop(context, LineResult.saved(_line));
      return;
    }
    _line
      ..designation = _designation.text.trim()
      ..unitName = _unit.text.trim().isEmpty ? null : _unit.text.trim()
      ..quantity = parseNumber(_quantity.text)!
      ..unitPrice = int.parse(_price.text);
    Navigator.pop(context, LineResult.saved(_line));
  }

  @override
  Widget build(BuildContext context) {
    final labor = _line.isLabor;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.isNew ? 'Nouvelle ligne' : 'Modifier la ligne', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'supply', label: Text('Fourniture'), icon: Icon(Icons.inventory_2_outlined)),
                  ButtonSegment(value: 'labor', label: Text('Main-d\'œuvre'), icon: Icon(Icons.handyman_outlined)),
                ],
                selected: {_line.kind},
                onSelectionChanged: (value) => _setKind(value.first),
              ),
              const SizedBox(height: 14),
              if (!labor) ...[
                TextFormField(
                  controller: _designation,
                  autofocus: widget.isNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Désignation'),
                  onChanged: _searchProducts,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Saisissez une désignation.' : null,
                ),
                if (_suggestions.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        for (final p in _suggestions)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.auto_awesome_outlined, size: 18),
                            title: Text(p.name),
                            trailing: p.unitPrice > 0 ? Text(formatMoney(p.unitPrice)) : null,
                            onTap: () => _useProduct(p),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: const InputDecoration(labelText: 'Quantité'),
                        validator: (v) => (parseNumber(v ?? '') ?? 0) <= 0 ? 'Quantité invalide.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unité'))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final unit in _units)
                      ActionChip(label: Text(unit), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _unit.text = unit)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _price,
                focusNode: _priceFocus,
                autofocus: widget.isNew && labor,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: labor ? 'Montant de la main-d\'œuvre' : 'Prix unitaire', suffixText: 'FCFA'),
                validator: (v) => labor
                    ? ((int.tryParse(v ?? '') ?? 0) <= 0 ? 'Saisissez le montant de la main-d\'œuvre.' : null)
                    : (int.tryParse(v ?? '') == null ? 'Saisissez le prix unitaire.' : null),
              ),
              if (!labor) ...[
                const SizedBox(height: 14),
                Text(
                  'Montant de la ligne : ${formatMoney(_subtotal)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!widget.isNew) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(context, LineResult.deleted()),
                        child: const Text('Supprimer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: FilledButton(onPressed: _submit, child: Text(widget.isNew ? 'Ajouter' : 'Valider'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
