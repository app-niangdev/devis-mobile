import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/common.dart';
import 'customer.dart';
import '../../core/theme/app_colors.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(text: widget.customer == null ? '' : formatPhone(widget.customer!.phone));
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _notes = TextEditingController(text: widget.customer?.notes);
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullable(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    // L'erreur du serveur ne s'applique qu'à la saisie précédente
    _error = null;
    if (!_formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      final customer = await context.read<CustomersRepository>().save(id: widget.customer?.id, data: {
        'name': _name.text.trim(),
        'phone': cleanPhone(_phone.text),
        'address': _nullable(_address),
        'email': _nullable(_email),
        'notes': _nullable(_notes),
      });
      if (!mounted) {
        return;
      }
      showMessage(context, widget.customer == null ? 'Client enregistré.' : 'Client modifié.');
      if (widget.customer == null) {
        context.pushReplacement('/customers/${customer.id}');
      } else {
        context.pop(true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e);
      _formKey.currentState!.validate();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer == null ? 'Nouveau client' : 'Modifier le client')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null && _error!.errors == null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!.message, style: TextStyle(color: AppColors.danger))),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom *'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Le nom du client est obligatoire.' : _error?.fieldError('name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [SenegalPhoneFormatter()],
              decoration: const InputDecoration(labelText: 'Téléphone *', hintText: '77 123 45 67', prefixText: '+221  '),
              validator: (v) => validatePhone(v) ?? _error?.fieldError('phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (_) => _error?.fieldError('email'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const ButtonSpinner()
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
