import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/format.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_theme.dart';
import '../company/company.dart';
import '../customers/customer.dart';
import 'line_sheet.dart';
import 'quote.dart';

/// Création ou modification d'un devis. Les totaux sont recalculés en direct ;
/// le serveur refait le calcul à l'enregistrement.
class QuoteEditorScreen extends StatefulWidget {
  const QuoteEditorScreen({super.key, this.quote, this.customerId});

  final Quote? quote;

  /// Client présélectionné (création depuis la fiche client).
  final int? customerId;

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _discount = TextEditingController();
  final _depositValue = TextEditingController();
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();

  bool _newCustomer = false;
  Customer? _customer;
  Map<String, dynamic>? _existingCustomer;
  final List<QuoteLine> _lines = [];
  String _depositType = 'none';
  DateTime? _validUntil;
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.quote != null;

  @override
  void initState() {
    super.initState();
    _discount.addListener(_refresh);
    _depositValue.addListener(_refresh);
    _init();
  }

  void _refresh() => setState(() {});

  Future<void> _init() async {
    final quote = widget.quote;
    try {
      if (quote != null) {
        _existingCustomer = quote.customer;
        _title.text = quote.title ?? '';
        _notes.text = quote.notes ?? '';
        _discount.text = quote.discount > 0 ? '${quote.discount}' : '';
        _depositType = quote.depositType;
        _depositValue.text = quote.depositValue > 0 ? '${quote.depositValue}' : '';
        _validUntil = DateTime.tryParse(quote.validUntil ?? '');
        _lines.addAll(quote.items.map((l) => l.copy()));
      } else {
        // Réglages de l'entreprise : acompte habituel et validité
        final company = await context.read<CompanyRepository>().get();
        _depositType = company.text('default_deposit_type').isEmpty ? 'none' : company.text('default_deposit_type');
        final value = company.number('default_deposit_value');
        _depositValue.text = value > 0 ? '$value' : '';
        _validUntil = DateTime.now().add(Duration(days: company.number('quote_validity_days', 30)));
        if (widget.customerId != null && mounted) {
          _customer = await context.read<CustomersRepository>().find(widget.customerId!);
        }
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _notes, _discount, _depositValue, _newName, _newPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _supplies => _lines.where((l) => !l.isLabor).fold(0, (sum, l) => sum + l.subtotal);
  int get _labor => _lines.where((l) => l.isLabor).fold(0, (sum, l) => sum + l.subtotal);
  int get _gross => _supplies + _labor;
  int get _discountValue => int.tryParse(_discount.text) ?? 0;
  int get _total => _gross - _discountValue;

  int get _depositAmount {
    final value = int.tryParse(_depositValue.text) ?? 0;
    return switch (_depositType) {
      'percent' => (_total * value / 100).round(),
      'amount' => value,
      _ => 0,
    };
  }

  String get _customerLabel {
    if (_customer != null) {
      return _customer!.name;
    }
    return _existingCustomer?['name'] as String? ?? '';
  }

  int? get _customerId => _customer?.id ?? _existingCustomer?['id'] as int?;

  Future<void> _pickCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomerPicker(),
    );
    if (customer != null) {
      setState(() {
        _customer = customer;
        _newCustomer = false;
      });
    }
  }

  Future<void> _editLine([int? index]) async {
    final result = await showLineSheet(
      context,
      index == null ? QuoteLine(kind: _lines.isNotEmpty ? _lines.last.kind : 'supply') : _lines[index].copy(),
      isNew: index == null,
    );
    if (result == null) {
      return;
    }
    setState(() {
      if (result.deleted) {
        _lines.removeAt(index!);
      } else if (index == null) {
        _lines.add(result.line!);
      } else {
        _lines[index] = result.line!;
      }
    });
  }

  Future<void> _pickValidity() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
    }
  }

  String? _check() {
    if (_newCustomer) {
      if (_newName.text.trim().length < 2) {
        return 'Saisissez le nom du client.';
      }
      final phoneError = validatePhone(_newPhone.text);
      if (phoneError != null) {
        return phoneError;
      }
    } else if (_customerId == null) {
      return 'Choisissez un client.';
    }
    if (_lines.isEmpty) {
      return 'Ajoutez au moins une ligne au devis.';
    }
    if (_discountValue > _gross) {
      return 'La remise ne peut pas dépasser le sous-total.';
    }
    if (_depositType == 'percent') {
      final value = int.tryParse(_depositValue.text) ?? 0;
      if (value < 1 || value > 100) {
        return 'Le pourcentage d\'acompte doit être compris entre 1 et 100.';
      }
    }
    if (_depositType == 'amount' && (_depositAmount <= 0 || _depositAmount > _total)) {
      return 'L\'acompte doit être supérieur à 0 et ne pas dépasser le total.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _check();
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'customer': _newCustomer
            ? {'mode': 'new', 'name': _newName.text.trim(), 'phone': cleanPhone(_newPhone.text)}
            : {'mode': 'existing', 'id': _customerId},
        'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
        'items': _lines.map((l) => l.toJson()).toList(),
        'discount': _discountValue,
        'deposit_type': _depositType,
        'deposit_value': _depositType == 'none' ? 0 : int.tryParse(_depositValue.text) ?? 0,
        'valid_until': _validUntil == null ? null : isoDate(_validUntil!),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      };
      final (quote, message) = await context.read<QuotesRepository>().save(id: widget.quote?.id, data: data);
      if (!mounted) {
        return;
      }
      showMessage(context, message);
      if (_editing) {
        context.pop(true);
      } else {
        context.pushReplacement('/quotes/${quote.id}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message, error: true);
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
      appBar: AppBar(title: Text(_editing ? 'Modifier ${widget.quote!.number}' : 'Nouveau devis')),
      body: _loading ? const LoadingView() : _form(),
      bottomNavigationBar: _loading ? null : _totalBar(),
    );
  }

  Widget _form() {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Client',
          trailing: TextButton(
            onPressed: () => setState(() => _newCustomer = !_newCustomer),
            child: Text(_newCustomer ? 'Client existant' : 'Nouveau client'),
          ),
          child: _newCustomer
              ? Column(
                  children: [
                    TextField(controller: _newName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom du client')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPhone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [SenegalPhoneFormatter()],
                      decoration: const InputDecoration(labelText: 'Téléphone', hintText: '77 123 45 67', prefixText: '+221  '),
                    ),
                  ],
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickCustomer,
                  child: InputDecorator(
                    decoration: const InputDecoration(suffixIcon: Icon(Icons.person_search_outlined)),
                    child: Text(
                      _customerLabel.isEmpty ? 'Choisir un client' : _customerLabel,
                      style: TextStyle(color: _customerLabel.isEmpty ? Colors.grey.shade600 : null, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Objet',
          child: TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex. Rénovation salle de bain'),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Lignes',
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Ajoutez les fournitures et la main-d\'œuvre.', style: TextStyle(color: Colors.grey.shade600)),
                ),
              for (var i = 0; i < _lines.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _editLine(i),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: (_lines[i].isLabor ? scheme.tertiary : scheme.primary).withValues(alpha: 0.16),
                    child: Icon(
                      _lines[i].isLabor ? Icons.handyman_outlined : Icons.inventory_2_outlined,
                      size: 18,
                      color: _lines[i].isLabor ? context.brand.accentInk : context.brand.primaryInk,
                    ),
                  ),
                  title: Text(_lines[i].designation, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: _lines[i].isLabor && _lines[i].quantity == 1
                      ? null
                      : Text('${formatQuantity(_lines[i].quantity)} ${_lines[i].unitName ?? ''} × ${formatMoney(_lines[i].unitPrice)}'),
                  trailing: Text(formatMoney(_lines[i].subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(onPressed: () => _editLine(), icon: const Icon(Icons.add), label: const Text('Ajouter une ligne')),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Remise et acompte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Remise', suffixText: 'FCFA'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'none', label: Text('Aucun')),
                  ButtonSegment(value: 'percent', label: Text('%')),
                  ButtonSegment(value: 'amount', label: Text('Montant')),
                ],
                selected: {_depositType},
                onSelectionChanged: (value) => setState(() => _depositType = value.first),
              ),
              if (_depositType != 'none') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _depositValue,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _depositType == 'percent' ? 'Pourcentage du total' : 'Montant de l\'acompte',
                    suffixText: _depositType == 'percent' ? '%' : 'FCFA',
                    helperText: _depositType == 'percent' ? 'Soit ${formatMoney(_depositAmount)}' : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Validité et conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _pickValidity,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Valable jusqu\'au', suffixIcon: Icon(Icons.event_outlined)),
                  child: Text(_validUntil == null ? 'Sans limite' : formatDate(isoDate(_validUntil!))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Conditions et remarques', alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _totalBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatMoney(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  if (_depositAmount > 0)
                    Text('Acompte ${formatMoney(_depositAmount)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const ButtonSpinner()
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recherche d'un client existant.
class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _search = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await context.read<CustomersRepository>().list(search: _search.text.trim(), sort: 'recent');
      if (mounted) {
        setState(() => _items = page.items);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nom ou téléphone', prefixIcon: Icon(Icons.search)),
                onChanged: (_) => _load(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const LoadingView()
                  : _items.isEmpty
                      ? const EmptyView(icon: Icons.person_off_outlined, message: 'Aucun client trouvé.\nUtilisez « Nouveau client ».')
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final c = _items[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())),
                              title: Text(c.name),
                              subtitle: Text(c.phoneDisplay),
                              onTap: () => Navigator.pop(context, c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
