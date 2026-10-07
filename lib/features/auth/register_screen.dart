import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/common.dart';
import 'auth_scaffold.dart';

/// Inscription d'un artisan : son entreprise et son compte.
/// Un code WhatsApp confirme le numéro, puis l'administrateur active le compte.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _trade = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _company, _trade, _phone, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final step = await context.read<Session>().register(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            companyName: _company.text.trim(),
            trade: _trade.text.trim().isEmpty ? null : _trade.text.trim(),
            phone: cleanPhone(_phone.text),
            password: _password.text,
            confirmation: _confirmation.text,
          );
      if (mounted && step.needsOtp) {
        context.push('/auth/otp', extra: step);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _required(String? value, String message) => (value == null || value.trim().length < 2) ? message : null;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Créer un compte',
      subtitle: 'Inscrivez votre entreprise. Votre numéro sera confirmé par un code WhatsApp, '
          'puis votre compte sera activé par l\'équipe SN Devis.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(_error!),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: (v) => _required(v, 'Le prénom est obligatoire.'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: (v) => _required(v, 'Le nom est obligatoire.'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _company,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.organizationName],
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'entreprise',
                  hintText: 'Ex. Menuiserie Diop',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) => _required(v, 'Le nom de l\'entreprise est obligatoire.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trade,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Métier (facultatif)',
                  hintText: 'Maçon, plombier, électricien…',
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [SenegalPhoneFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Numéro WhatsApp',
                  hintText: '77 123 45 67',
                  helperText: 'Il vous servira à vous connecter.',
                  prefixText: '+221  ',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                ),
                validator: validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  helperText: '8 caractères minimum',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? 'Le mot de passe doit contenir au moins 8 caractères.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmation,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => v != _password.text ? 'La confirmation ne correspond pas.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const ButtonSpinner() : const Text('Recevoir mon code WhatsApp'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('J\'ai déjà un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
