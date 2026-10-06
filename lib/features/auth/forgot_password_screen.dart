import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/common.dart';
import '../../core/utils/phone.dart';
import 'auth_scaffold.dart';

/// Mot de passe oublié : un code est envoyé sur WhatsApp au numéro saisi.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
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
      final step = await context.read<Session>().forgotPassword(cleanPhone(_phone.text));
      if (mounted) {
        context.pushReplacement('/auth/otp', extra: step);
      }
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
    return AuthScaffold(
      showBack: true,
      title: 'Mot de passe oublié',
      subtitle: 'Saisissez votre numéro : nous vous enverrons un code de vérification sur WhatsApp.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBanner(_error!),
            TextFormField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [SenegalPhoneFormatter()],
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: '77 123 45 67',
                prefixText: '+221  ',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
              validator: validatePhone,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const ButtonSpinner()
                  : const Text('Recevoir le code'),
            ),
          ],
        ),
      ),
    );
  }
}
