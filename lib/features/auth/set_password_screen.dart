import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/common.dart';
import 'auth_scaffold.dart';

/// Choix du mot de passe après le code WhatsApp.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.step});

  final AuthStep step;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
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
      await context.read<Session>().setPassword(widget.step.resetToken!, _password.text, _confirmation.text);
      // Connecté : le routeur ouvre l'accueil
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstLogin = widget.step.purpose == 'first_login';

    return AuthScaffold(
      title: firstLogin ? 'Choisissez votre mot de passe' : 'Nouveau mot de passe',
      subtitle: firstLogin
          ? 'Votre numéro est confirmé. Choisissez le mot de passe que vous utiliserez pour vous connecter.'
          : 'Code vérifié. Choisissez votre nouveau mot de passe : vos autres sessions seront fermées.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(_error!),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                helperText: '8 caractères minimum',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
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
              decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (v) => v != _password.text ? 'La confirmation ne correspond pas.' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const ButtonSpinner()
                  : const Text('Enregistrer et continuer'),
            ),
          ],
        ),
      ),
    );
  }
}
