import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/common.dart';
import 'auth_scaffold.dart';
import '../../core/theme/app_colors.dart';

/// Saisie du code reçu sur WhatsApp (première connexion, numéro modifié, mot de passe oublié).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.step});

  final AuthStep step;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  late AuthStep _step = widget.step;
  late int _resendIn = widget.step.resendIn;
  Timer? _timer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
    });
  }

  String get _title => switch (_step.purpose) {
        'first_login' => 'Activez votre compte',
        'password_reset' => 'Mot de passe oublié',
        _ => 'Confirmez votre numéro',
      };

  Future<void> _verify() async {
    if (_code.text.length != 6 || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final next = await context.read<Session>().verifyOtp(_step.challengeToken!, _code.text);
      if (!mounted) {
        return;
      }
      if (next.needsPassword) {
        context.pushReplacement('/auth/password', extra: next);
      }
      // Numéro confirmé : connecté, le routeur ouvre l'accueil
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _code.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resend() async {
    try {
      final step = await context.read<Session>().resendOtp(_step.challengeToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _step = step;
        _resendIn = step.resendIn;
        _error = null;
        _code.clear();
      });
      _startTimer();
      showMessage(context, 'Un nouveau code vous a été envoyé sur WhatsApp.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      final wait = e.payload is Map ? (e.payload as Map)['resend_in'] : null;
      if (wait is int) {
        setState(() => _resendIn = wait);
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return AuthScaffold(
      showBack: true,
      title: _title,
      subtitle: 'Saisissez le code à 6 chiffres envoyé sur WhatsApp au ${_step.phoneMasked ?? 'numéro indiqué'}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ErrorBanner(_error!),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 14),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (value) {
              setState(() {});
              if (value.length == 6) {
                _verify();
              }
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading || _code.text.length != 6 ? null : _verify,
            child: _loading
                ? const ButtonSpinner()
                : const Text('Valider le code'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              _resendIn > 0
                  ? Text('Renvoyer le code dans $_resendIn s', style: TextStyle(color: AppColors.textSecondary))
                  : TextButton(onPressed: _resend, child: const Text('Renvoyer le code')),
            ],
          ),
        ],
      ),
    );
  }
}
