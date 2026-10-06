import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/common.dart';
import '../../core/utils/phone.dart';
import '../subscription/subscription_offers.dart';
import 'auth_scaffold.dart';

/// Connexion du gestionnaire : téléphone + mot de passe.
/// À la première connexion, un code WhatsApp est demandé avant de choisir son mot de passe.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// Abonnement expiré : on affiche les forfaits et le contact sous le message.
  bool _subscriptionExpired = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _error = session.endedMessage;
    _subscriptionExpired = session.endedCode == 'SUBSCRIPTION_EXPIRED';
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _subscriptionExpired = false;
    });

    try {
      final step = await context.read<Session>().login(cleanPhone(_phone.text), _password.text);
      if (!mounted) {
        return;
      }
      if (step.needsOtp) {
        context.push('/auth/otp', extra: step);
      }
      // Connecté : le routeur ouvre l'accueil
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _subscriptionExpired = e.code == 'SUBSCRIPTION_EXPIRED';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Connexion',
      subtitle: 'Gérez vos clients et vos devis depuis votre téléphone.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(_error!),
            if (_subscriptionExpired) ...[
              OffersPanel(api: context.read<Session>().api),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [SenegalPhoneFormatter()],
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: '77 123 45 67',
                prefixText: '+221  ',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
              validator: validatePhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Le mot de passe est obligatoire.' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/auth/forgot'),
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const ButtonSpinner()
                  : const Text('Se connecter'),
            ),
            const SizedBox(height: 24),
            Text(
              'Première connexion ? Utilisez le mot de passe provisoire reçu de l\'administrateur : '
              'un code vous sera envoyé sur WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
